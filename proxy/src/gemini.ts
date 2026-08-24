// Вызов Gemini, валидация и обрезка ответа — research.md R6, R16.

import { REACTION_TONES, type Env, type ReactionTone } from "./types";

export type GeminiResult =
  | { kind: "ok"; value: { mood: ReactionTone; reply: string; intensity: number } }
  | { kind: "rate_limited" }
  | { kind: "invalid" };

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    mood: {
      type: "STRING",
      enum: REACTION_TONES,
      description:
        "Тон ТВОЕЙ реплики как персонажа (см. ReactionTone в коде приложения). " +
        "Это не оценка настроения пользователя и не число.",
    },
    reply: { type: "STRING" },
    intensity: {
      type: "NUMBER",
      minimum: 0.0,
      maximum: 1.0,
      description:
        "Амплитуда анимации: 0.0 — почти неподвижен, 1.0 — максимально оживлён. Дробное число.",
    },
  },
  required: ["mood", "reply", "intensity"],
} as const;

export async function callGeminiOnce(
  env: Env,
  model: string,
  systemPrompt: string,
  moodScore: number,
  dayText: string,
  maxReplyLength: number,
): Promise<GeminiResult> {
  const requestBody = {
    systemInstruction: { parts: [{ text: systemPrompt }] },
    contents: [
      { parts: [{ text: `Оценка настроения по шкале 1-5: ${moodScore}. Текст о дне: ${dayText}` }] },
    ],
    generationConfig: {
      thinkingConfig: { thinkingLevel: "minimal" },
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  };

  let response: Response;
  try {
    response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": env.GEMINI_API_KEY,
        },
        body: JSON.stringify(requestBody),
      },
    );
  } catch {
    return { kind: "invalid" };
  }

  if (response.status === 429) return { kind: "rate_limited" };
  if (!response.ok) return { kind: "invalid" };

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return { kind: "invalid" };
  }

  return parseGeminiPayload(payload, maxReplyLength);
}

export function parseGeminiPayload(payload: unknown, maxReplyLength: number): GeminiResult {
  if (typeof payload !== "object" || payload === null) return { kind: "invalid" };
  const candidates = (payload as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return { kind: "invalid" };

  const candidate = candidates[0] as {
    finishReason?: unknown;
    content?: { parts?: Array<{ text?: unknown }> };
  };
  if (candidate.finishReason !== "STOP") return { kind: "invalid" };

  const text = candidate.content?.parts?.[0]?.text;
  if (typeof text !== "string") return { kind: "invalid" };

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { kind: "invalid" };
  }
  if (typeof parsed !== "object" || parsed === null) return { kind: "invalid" };

  const obj = parsed as { mood?: unknown; reply?: unknown; intensity?: unknown };

  if (typeof obj.mood !== "string" || !isReactionTone(obj.mood)) return { kind: "invalid" };
  if (typeof obj.reply !== "string" || obj.reply.trim().length === 0) return { kind: "invalid" };

  const rawIntensity = typeof obj.intensity === "number" ? obj.intensity : NaN;
  if (Number.isNaN(rawIntensity)) return { kind: "invalid" };
  const intensity = Math.min(1, Math.max(0, rawIntensity));

  const reply = trimToWordBoundary(obj.reply, maxReplyLength);

  return { kind: "ok", value: { mood: obj.mood, reply, intensity } };
}

function isReactionTone(value: string): value is ReactionTone {
  return (REACTION_TONES as readonly string[]).includes(value);
}

/** Обрезка по границе слова, не по символу (FR-006, FR-006a). */
export function trimToWordBoundary(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  const cut = text.slice(0, maxLength);
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trimEnd();
}
