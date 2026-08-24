import { env } from "cloudflare:test";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { handleReact } from "../src/react";
import type { Env } from "../src/types";
import { clearTables, ensureSchema } from "./schema";

const VALID_ID = "aa57b3b6078bc2b81489387716ec0762";

const PROMPTS = {
  commonPrefix: "префикс",
  personas: {
    hippo: { systemPrompt: "бегемот", anchors: ["a0", "a1", "a2", "a3", "a4", "a5"], maxReplyLength: 220 },
  },
};

const APP_CONFIG = {
  aiEnabled: true,
  models: ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"],
  dailyCapOverride: 400,
  perDeviceCapOverride: 15,
};

function request(body: Record<string, unknown>): Request {
  return new Request("http://proxy.test/react", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function validBody(overrides: Record<string, unknown> = {}) {
  return {
    installId: VALID_ID,
    characterId: "hippo",
    moodScore: 3,
    dayText: "Обычный день",
    attempt: 0,
    ...overrides,
  };
}

function mockGeminiSuccess() {
  return vi.fn(async (input: RequestInfo | URL) => {
    const url = input.toString();
    if (url.includes("generativelanguage.googleapis.com")) {
      return new Response(
        JSON.stringify({
          candidates: [
            {
              finishReason: "STOP",
              content: {
                parts: [{ text: JSON.stringify({ mood: "warm", reply: "всё хорошо", intensity: 0.4 }) }],
              },
            },
          ],
        }),
        { status: 200 },
      );
    }
    throw new Error(`неожиданный fetch в тесте: ${url}`);
  });
}

async function seedConfig(app: Record<string, unknown> = APP_CONFIG) {
  await env.CONFIG.put("config:prompts", JSON.stringify(PROMPTS));
  await env.CONFIG.put("config:app", JSON.stringify(app));
}

beforeEach(async () => {
  await ensureSchema();
  await clearTables();
  await env.CONFIG.delete("config:app");
  await env.CONFIG.delete("config:prompts");
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("POST /react — 200 (contracts/react-api.md §3)", () => {
  it("корректный запрос даёт ответ формы контракта", async () => {
    await seedConfig();
    vi.stubGlobal("fetch", mockGeminiSuccess());

    const response = await handleReact(request(validBody()), env as unknown as Env);
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toEqual({ character: "hippo", mood: "warm", reply: "всё хорошо", intensity: 0.4 });
  });
});

describe("POST /react — 400", () => {
  it("некорректное тело — к Gemini обращения нет", async () => {
    await seedConfig();
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const response = await handleReact(request(validBody({ moodScore: 99 })), env as unknown as Env);
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "bad_request" });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("POST /react — 403 (US2)", () => {
  it("продовый контур без integrityToken отклоняет запрос, счётчики не растут", async () => {
    await seedConfig();
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const prodEnv = { ...env, ENVIRONMENT: "production", ALLOW_UNVERIFIED_INTEGRITY: undefined };
    const response = await handleReact(request(validBody()), prodEnv as unknown as Env);

    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: "integrity_failed" });
    expect(fetchMock).not.toHaveBeenCalled();

    const rows = await env.DB.prepare("SELECT * FROM rate_limits").all();
    expect(rows.results).toHaveLength(0);
  });
});

describe("POST /react — 429 (US2)", () => {
  it("scope: device — персональный предел исчерпан", async () => {
    await seedConfig({ ...APP_CONFIG, perDeviceCapOverride: 1 });
    vi.stubGlobal("fetch", mockGeminiSuccess());

    const first = await handleReact(request(validBody()), env as unknown as Env);
    expect(first.status).toBe(200);

    const second = await handleReact(request(validBody({ attempt: 1 })), env as unknown as Env);
    expect(second.status).toBe(429);
    const body = await second.json();
    expect(body).toMatchObject({ error: "rate_limited", scope: "device" });
    expect(typeof (body as { retryAfterSeconds: number }).retryAfterSeconds).toBe("number");
  });

  it("scope: global — общий предел модели исчерпан, другое устройство продолжает работать не может", async () => {
    await seedConfig({ ...APP_CONFIG, models: ["only-model"], dailyCapOverride: 1 });
    vi.stubGlobal("fetch", mockGeminiSuccess());

    const first = await handleReact(request(validBody({ installId: VALID_ID })), env as unknown as Env);
    expect(first.status).toBe(200);

    const otherId = "d1d70da63e2d8da1e017f8131a68d974";
    const second = await handleReact(request(validBody({ installId: otherId })), env as unknown as Env);
    expect(second.status).toBe(429);
    expect(await second.json()).toMatchObject({ error: "rate_limited", scope: "global" });
  });
});

describe("POST /react — 503 (US2)", () => {
  it("aiEnabled: false — 503, к Gemini обращения нет, счётчики не трогаем до этого шага", async () => {
    await seedConfig({ ...APP_CONFIG, aiEnabled: false });
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const response = await handleReact(request(validBody()), env as unknown as Env);
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({ error: "ai_disabled" });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("POST /react — 500", () => {
  it("config:prompts недоступен/отсутствует — 500 internal, не дефолт", async () => {
    await env.CONFIG.delete("config:prompts");
    const response = await handleReact(request(validBody()), env as unknown as Env);
    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "internal" });
  });
});

describe("POST /react — 422", () => {
  it("Gemini дважды вернул непригодный ответ", async () => {
    await seedConfig();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ candidates: [] }), { status: 200 })),
    );

    const response = await handleReact(request(validBody()), env as unknown as Env);
    expect(response.status).toBe(422);
    expect(await response.json()).toEqual({ error: "invalid_ai_response" });
  });
});
