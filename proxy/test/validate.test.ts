import { describe, expect, it } from "vitest";
import { validateReactRequest } from "../src/validate";

const KNOWN = ["cat", "dog", "crocodile", "hippo"];
const VALID_ID = "aa57b3b6078bc2b81489387716ec0762";

function base(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    installId: VALID_ID,
    characterId: "hippo",
    moodScore: 3,
    dayText: "Обычный день",
    attempt: 0,
    ...overrides,
  };
}

describe("validateReactRequest", () => {
  it("принимает корректный запрос", () => {
    const result = validateReactRequest(base(), KNOWN);
    expect(result.ok).toBe(true);
  });

  it("отсутствие attempt даёт 0", () => {
    const { attempt: _attempt, ...withoutAttempt } = base();
    const result = validateReactRequest(withoutAttempt, KNOWN);
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.attempt).toBe(0);
  });

  it.each([
    ["не 32 hex", { installId: "too-short" }],
    ["неизвестный characterId", { characterId: "unicorn" }],
    ["moodScore вне 1-5", { moodScore: 7 }],
    ["moodScore дробный", { moodScore: 2.5 }],
    ["moodScore отсутствует", { moodScore: undefined }],
    ["dayText пустой", { dayText: "" }],
    ["dayText только пробелы", { dayText: "   " }],
    ["dayText длиннее 2000", { dayText: "а".repeat(2001) }],
    ["attempt отрицательный", { attempt: -1 }],
    ["attempt дробный", { attempt: 1.5 }],
    ["integrityToken не строка", { integrityToken: 123 }],
  ])("отклоняет: %s", (_label, overrides) => {
    const result = validateReactRequest(base(overrides), KNOWN);
    expect(result.ok).toBe(false);
  });

  it("dayText ровно 2000 символов проходит", () => {
    const result = validateReactRequest(base({ dayText: "а".repeat(2000) }), KNOWN);
    expect(result.ok).toBe(true);
  });

  it("тело не объект отклоняется", () => {
    expect(validateReactRequest(null, KNOWN).ok).toBe(false);
    expect(validateReactRequest("string", KNOWN).ok).toBe(false);
    expect(validateReactRequest([], KNOWN).ok).toBe(false);
  });
});
