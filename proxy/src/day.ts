// Ключ суток — research.md R9: вычисляется один раз за запрос, UTC, передаётся значением.

const MS_PER_DAY = 86_400_000;

/** 'yyyy-mm-dd' в UTC. */
export function dayKey(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/** Номер дня в году (1-366), UTC — вход для выбора якоря (research.md R15). */
export function dayOfYear(now: Date): number {
  const startOfYear = Date.UTC(now.getUTCFullYear(), 0, 1);
  const startOfDay = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  return Math.floor((startOfDay - startOfYear) / MS_PER_DAY) + 1;
}

/** 'yyyy-mm-dd' — порог очистки: сегодня минус [daysToKeep] суток (research.md R10). */
export function cleanupThreshold(now: Date, daysToKeep = 7): string {
  return dayKey(new Date(now.getTime() - daysToKeep * MS_PER_DAY));
}
