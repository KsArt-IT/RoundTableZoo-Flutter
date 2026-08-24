// Обработчик POST /react — порядок шагов contracts/react-api.md §2.

import { readAppConfig, readPromptsConfig } from "./config";
import { dayKey, secondsUntilNextUtcDay } from "./day";
import { callGeminiOnce } from "./gemini";
import { verifyIntegrity } from "./integrity";
import { incrementDeviceCount, incrementGlobalCount } from "./limits";
import { selectModel } from "./models";
import { buildPrompt } from "./prompt";
import type { Env, FailureCode, ReactResponse } from "./types";
import { validateReactRequest } from "./validate";

const GEMINI_RATE_LIMIT_RETRY_DELAY_MS = 2000;

function errorResponse(
  status: number,
  error: FailureCode,
  extra?: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify({ error, ...extra }), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function isDevBypassActive(env: Env): boolean {
  return env.ENVIRONMENT === "dev" && Boolean(env.ALLOW_UNVERIFIED_INTEGRITY);
}

export async function handleReact(request: Request, env: Env): Promise<Response> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse(400, "bad_request");
  }

  // Шаг 1 (часть) — состав известных персонажей приходит из config:prompts,
  // поэтому его чтение предшествует валидации формы запроса.
  const promptsResult = await readPromptsConfig(env);
  if (!promptsResult.ok) return errorResponse(500, "internal");
  const prompts = promptsResult.value;
  const knownCharacterIds = Object.keys(prompts.personas);

  // Шаг 1 — валидация тела.
  const validation = validateReactRequest(body, knownCharacterIds);
  if (!validation.ok) return errorResponse(400, "bad_request");
  const req = validation.value;

  // Шаг 2 — kill switch.
  const appConfigResult = await readAppConfig(env);
  if (!appConfigResult.ok) return errorResponse(500, "internal");
  const appConfig = appConfigResult.value;
  if (!appConfig.aiEnabled) {
    return errorResponse(503, "ai_disabled", { message: "AI-функция временно отключена" });
  }

  // Шаг 3 — подтверждение подлинности (пропускается только в отладочном контуре).
  if (!isDevBypassActive(env)) {
    const verified = await verifyIntegrity(env, req.integrityToken);
    if (!verified) return errorResponse(403, "integrity_failed");
  }

  const now = new Date();
  const day = dayKey(now);

  // Шаг 4 — персональный лимит.
  let deviceCount: number;
  try {
    deviceCount = await incrementDeviceCount(env, day, req.installId);
  } catch {
    return errorResponse(500, "internal");
  }
  if (deviceCount > appConfig.perDeviceCapOverride) {
    return errorResponse(429, "rate_limited", {
      scope: "device",
      retryAfterSeconds: secondsUntilNextUtcDay(now),
    });
  }

  // Шаг 5-6 — выбор модели (общий лимит) + вызов Gemini, с переключением на
  // резерв как при исчерпанном счётчике, так и при 429 от провайдера (R19).
  const { systemPrompt, maxReplyLength } = buildPrompt(prompts, req.characterId, req.attempt, now);

  let anyModelHadCapacity = false;
  let outcome: ReactResponse | null = null;
  let remainingModels = appConfig.models;

  while (remainingModels.length > 0) {
    let selection: Awaited<ReturnType<typeof selectModel>>;
    try {
      selection = await selectModel(remainingModels, appConfig.dailyCapOverride, (model) =>
        incrementGlobalCount(env, day, model),
      );
    } catch {
      return errorResponse(500, "internal");
    }
    if (!selection.ok) break; // ни у одной оставшейся модели нет квоты
    anyModelHadCapacity = true;
    const model = selection.model;
    const callGemini = () =>
      callGeminiOnce(env, model, systemPrompt, req.moodScore, req.dayText, maxReplyLength);

    let result = await callGemini();

    if (result.kind === "rate_limited") {
      await sleep(GEMINI_RATE_LIMIT_RETRY_DELAY_MS);
      result = await callGemini();
    }
    if (result.kind === "rate_limited") {
      // выбитый RPM провайдера — следующая модель (R19), уже опробованные
      // (включая эту) из списка кандидатов больше не выбираются
      remainingModels = remainingModels.slice(remainingModels.indexOf(model) + 1);
      continue;
    }

    if (result.kind === "invalid") {
      const retry = await callGemini();
      if (retry.kind !== "ok") return errorResponse(422, "invalid_ai_response");
      outcome = { character: req.characterId, ...retry.value };
      break;
    }

    outcome = { character: req.characterId, ...result.value };
    break;
  }

  if (outcome === null) {
    if (!anyModelHadCapacity) {
      return errorResponse(429, "rate_limited", {
        scope: "global",
        retryAfterSeconds: secondsUntilNextUtcDay(now),
      });
    }
    // Список моделей исчерпан 429-ми от провайдера — это не "твой лимит",
    // а сбой самого ответа AI с точки зрения клиента (R19).
    return errorResponse(422, "invalid_ai_response");
  }

  return new Response(JSON.stringify(outcome), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
