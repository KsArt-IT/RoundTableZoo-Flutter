import { afterEach, describe, expect, it, vi } from "vitest";
import { callGeminiOnce, parseGeminiPayload, trimToWordBoundary } from "../src/gemini";
import type { Env } from "../src/types";

const ENV = { GEMINI_API_KEY: "test-key" } as Env;

function candidatePayload(overrides: Record<string, unknown> = {}) {
  return {
    candidates: [
      {
        finishReason: "STOP",
        content: { parts: [{ text: JSON.stringify({ mood: "warm", reply: "привет", intensity: 0.5 }) }] },
        ...overrides,
      },
    ],
  };
}

describe("parseGeminiPayload — валидация ответа модели (research.md R16)", () => {
  it("принимает валидный ответ", () => {
    const result = parseGeminiPayload(candidatePayload(), 220);
    expect(result.kind).toBe("ok");
  });

  it("mood вне ReactionTone отбраковывается", () => {
    const payload = candidatePayload({
      content: { parts: [{ text: JSON.stringify({ mood: "annoyed", reply: "x", intensity: 0.5 }) }] },
    });
    expect(parseGeminiPayload(payload, 220).kind).toBe("invalid");
  });

  it("intensity=2 клампится к 1.0", () => {
    const payload = candidatePayload({
      content: { parts: [{ text: JSON.stringify({ mood: "warm", reply: "x", intensity: 2 }) }] },
    });
    const result = parseGeminiPayload(payload, 220);
    expect(result.kind).toBe("ok");
    if (result.kind === "ok") expect(result.value.intensity).toBe(1);
  });

  it("intensity=NaN (через строку) отбраковывается", () => {
    const payload = candidatePayload({
      content: { parts: [{ text: JSON.stringify({ mood: "warm", reply: "x", intensity: "два" }) }] },
    });
    expect(parseGeminiPayload(payload, 220).kind).toBe("invalid");
  });

  it("finishReason MAX_TOKENS отбраковывается", () => {
    const payload = candidatePayload({ finishReason: "MAX_TOKENS" });
    expect(parseGeminiPayload(payload, 220).kind).toBe("invalid");
  });

  it("пустой candidates отбраковывается", () => {
    expect(parseGeminiPayload({ candidates: [] }, 220).kind).toBe("invalid");
  });

  it("character в ответе модели игнорируется — подставляется вызывающей стороной", () => {
    const payload = candidatePayload({
      content: {
        parts: [{ text: JSON.stringify({ mood: "warm", reply: "x", intensity: 0.5, character: "cat" }) }],
      },
    });
    const result = parseGeminiPayload(payload, 220);
    expect(result.kind).toBe("ok");
    if (result.kind === "ok") expect(result.value).not.toHaveProperty("character");
  });
});

describe("trimToWordBoundary — обрезка реплики (FR-006, FR-006a)", () => {
  it("не трогает короткий текст", () => {
    expect(trimToWordBoundary("привет мир", 220)).toBe("привет мир");
  });

  it("режет по границе слова, не по символу", () => {
    const text = "раз два три четыре пять";
    const trimmed = trimToWordBoundary(text, 10);
    expect(text.startsWith(trimmed)).toBe(true);
    expect(trimmed.endsWith(" ")).toBe(false);
    expect(text[trimmed.length]).not.toBeUndefined();
  });
});

describe("callGeminiOnce", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("429 от Gemini даёт kind: rate_limited", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("rate limited", { status: 429 })),
    );
    const result = await callGeminiOnce(ENV, "gemini-3.5-flash-lite", "sys", 3, "текст", 220);
    expect(result.kind).toBe("rate_limited");
  });

  it("успешный ответ парсится и обрезается", async () => {
    const longReply = "слово ".repeat(50).trim();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify(
            candidatePayload({
              content: {
                parts: [{ text: JSON.stringify({ mood: "playful", reply: longReply, intensity: 0.7 }) }],
              },
            }),
          ),
          { status: 200 },
        ),
      ),
    );
    const result = await callGeminiOnce(ENV, "gemini-3.5-flash-lite", "sys", 3, "текст", 20);
    expect(result.kind).toBe("ok");
    if (result.kind === "ok") expect(result.value.reply.length).toBeLessThanOrEqual(20);
  });

  it("сбой сети даёт kind: invalid, а не исключение", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new Error("network down");
      }),
    );
    const result = await callGeminiOnce(ENV, "gemini-3.5-flash-lite", "sys", 3, "текст", 220);
    expect(result.kind).toBe("invalid");
  });
});
