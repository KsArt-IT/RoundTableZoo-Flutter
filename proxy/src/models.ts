// Выбор модели строго по приоритету — FR-007a, research.md R19.
// Чередование (round-robin) не применяется: манера персонажа не должна
// скакать через реплику при равноправном выборе между моделями.

export type ModelSelection = { ok: true; model: string } | { ok: false };

/**
 * Перебирает [models] по приоритету, увеличивая общий счётчик каждой
 * через [increment] и останавливаясь на первой, чей результирующий счётчик
 * не превысил [dailyCap]. Увеличение уже исчерпанной модели сверх кап —
 * безвредный побочный эффект: она и так заблокирована для выбора.
 */
export async function selectModel(
  models: readonly string[],
  dailyCap: number,
  increment: (model: string) => Promise<number>,
): Promise<ModelSelection> {
  for (const model of models) {
    const count = await increment(model);
    if (count <= dailyCap) return { ok: true, model };
  }
  return { ok: false };
}
