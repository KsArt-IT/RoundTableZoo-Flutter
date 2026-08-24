// Атомарные инкременты счётчиков — data-model.md §1.1-1.2, research.md R8.
// Один запрос на таблицу: INSERT ... ON CONFLICT ... RETURNING count.
// D1 однопоточен на запись, поэтому отдельная транзакция не нужна (R8).

import type { Env } from "./types";

export async function incrementDeviceCount(
  env: Env,
  day: string,
  installId: string,
): Promise<number> {
  const row = await env.DB.prepare(
    `INSERT INTO rate_limits (day, install_id, count) VALUES (?1, ?2, 1)
     ON CONFLICT(day, install_id) DO UPDATE SET count = count + 1
     RETURNING count`,
  )
    .bind(day, installId)
    .first<{ count: number }>();
  if (row === null) throw new Error("rate_limits: увеличение не вернуло строку");
  return row.count;
}

export async function incrementGlobalCount(
  env: Env,
  day: string,
  model: string,
): Promise<number> {
  const row = await env.DB.prepare(
    `INSERT INTO global_limits (day, model, count) VALUES (?1, ?2, 1)
     ON CONFLICT(day, model) DO UPDATE SET count = count + 1
     RETURNING count`,
  )
    .bind(day, model)
    .first<{ count: number }>();
  if (row === null) throw new Error("global_limits: увеличение не вернуло строку");
  return row.count;
}
