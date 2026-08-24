// Схема для тестов — то же самое, что migrations/0001_init.sql, но применяется
// напрямую через D1 binding в тестах, а не через `wrangler d1 migrations apply`.

import { env } from "cloudflare:test";

const STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS rate_limits (
     day        TEXT    NOT NULL,
     install_id TEXT    NOT NULL,
     count      INTEGER NOT NULL,
     PRIMARY KEY (day, install_id)
   )`,
  `CREATE TABLE IF NOT EXISTS global_limits (
     day   TEXT    NOT NULL,
     model TEXT    NOT NULL,
     count INTEGER NOT NULL,
     PRIMARY KEY (day, model)
   )`,
];

export async function ensureSchema(): Promise<void> {
  for (const statement of STATEMENTS) {
    await env.DB.prepare(statement).run();
  }
}

export async function clearTables(): Promise<void> {
  await env.DB.prepare("DELETE FROM rate_limits").run();
  await env.DB.prepare("DELETE FROM global_limits").run();
}
