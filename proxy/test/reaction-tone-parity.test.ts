// research.md R18 (missing) — ничто раньше не ловило расхождение REACTION_TONES
// со значениями ReactionTone на клиенте, если поменять только одну сторону.
// Файловой системы в рантайме Workers нет — исходник Dart подключается через
// Vite `?raw`, как wrangler.toml в env.test.ts.

import { describe, expect, it } from "vitest";
import dartSource from "../../app/lib/domain/value_objects/reaction_tone.dart?raw";
import { REACTION_TONES } from "../src/types";

describe("REACTION_TONES совпадает с ReactionTone клиента (T067)", () => {
  it("буквально совпадает по составу и порядку", () => {
    const enumBody = dartSource.match(/enum ReactionTone \{([\s\S]*?)\}/)?.[1];
    if (!enumBody) {
      throw new Error("Не найдено тело enum ReactionTone в reaction_tone.dart");
    }

    const valuesSection = enumBody.split(";")[0];
    const dartValues = valuesSection
      .split(",")
      .map((entry) => entry.trim())
      .filter((entry) => entry.length > 0);

    expect(dartValues).toEqual([...REACTION_TONES]);
  });
});
