// Разбор и валидация тела запроса — contracts/react-api.md §1.
// Все поля трактуются как недоверенный ввод (FR-007): тип, форма и границы
// проверяются явно, ничего не приводится неявным приведением типов.

import type { ReactRequest } from "./types";

export type ValidationResult = { ok: true; value: ReactRequest } | { ok: false };

const INSTALL_ID_RE = /^[0-9a-f]{32}$/i;
const MAX_DAY_TEXT_LENGTH = 2000;

export function validateReactRequest(
  body: unknown,
  knownCharacterIds: readonly string[],
): ValidationResult {
  if (typeof body !== "object" || body === null) return { ok: false };
  const b = body as Record<string, unknown>;

  if (typeof b.installId !== "string" || !INSTALL_ID_RE.test(b.installId)) {
    return { ok: false };
  }

  if (typeof b.characterId !== "string" || !knownCharacterIds.includes(b.characterId)) {
    return { ok: false };
  }

  if (
    typeof b.moodScore !== "number" ||
    !Number.isInteger(b.moodScore) ||
    b.moodScore < 1 ||
    b.moodScore > 5
  ) {
    return { ok: false };
  }

  if (typeof b.dayText !== "string" || b.dayText.length > MAX_DAY_TEXT_LENGTH) {
    return { ok: false };
  }
  if (b.dayText.trim().length === 0) return { ok: false };

  let attempt = 0;
  if (b.attempt !== undefined) {
    if (typeof b.attempt !== "number" || !Number.isInteger(b.attempt) || b.attempt < 0) {
      return { ok: false };
    }
    attempt = b.attempt;
  }

  let integrityToken: string | undefined;
  if (b.integrityToken !== undefined) {
    if (typeof b.integrityToken !== "string") return { ok: false };
    integrityToken = b.integrityToken;
  }

  return {
    ok: true,
    value: {
      installId: b.installId,
      characterId: b.characterId,
      moodScore: b.moodScore,
      dayText: b.dayText,
      attempt,
      integrityToken,
    },
  };
}
