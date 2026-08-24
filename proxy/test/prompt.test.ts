import { describe, expect, it } from "vitest";
import type { PromptsConfig } from "../src/config";
import { buildPrompt, pickAnchor } from "../src/prompt";

const PROMPTS: PromptsConfig = {
  commonPrefix: "ПРЕФИКС",
  personas: {
    hippo: {
      systemPrompt: "ПЕРСОНА",
      anchors: ["a0", "a1", "a2", "a3", "a4", "a5"],
      maxReplyLength: 220,
    },
  },
};

describe("buildPrompt", () => {
  it("склеивает префикс + персону + якорь в заданном порядке", () => {
    const { systemPrompt } = buildPrompt(PROMPTS, "hippo", 0, new Date("2026-01-01T00:00:00Z"));
    const prefixIdx = systemPrompt.indexOf("ПРЕФИКС");
    const personaIdx = systemPrompt.indexOf("ПЕРСОНА");
    const anchorIdx = systemPrompt.indexOf("Образ этой реплики:");
    expect(prefixIdx).toBeGreaterThanOrEqual(0);
    expect(personaIdx).toBeGreaterThan(prefixIdx);
    expect(anchorIdx).toBeGreaterThan(personaIdx);
  });

  it("возвращает maxReplyLength персонажа", () => {
    const { maxReplyLength } = buildPrompt(PROMPTS, "hippo", 0, new Date());
    expect(maxReplyLength).toBe(220);
  });

  it("неизвестный characterId бросает исключение", () => {
    expect(() => buildPrompt(PROMPTS, "unicorn", 0, new Date())).toThrow();
  });
});

describe("pickAnchor — ротация (research.md R15, SC-003a)", () => {
  const anchors = ["a0", "a1", "a2", "a3", "a4", "a5"];
  const day = new Date("2026-01-01T00:00:00Z"); // dayOfYear = 1

  it("attempt 0..5 даёт шесть разных якорей", () => {
    const picked = [0, 1, 2, 3, 4, 5].map((attempt) => pickAnchor(anchors, attempt, day));
    expect(new Set(picked).size).toBe(6);
  });

  it("седьмой запрос (attempt=6) замыкает круг на первый якорь того же дня", () => {
    const first = pickAnchor(anchors, 0, day);
    const seventh = pickAnchor(anchors, 6, day);
    expect(seventh).toBe(first);
  });
});
