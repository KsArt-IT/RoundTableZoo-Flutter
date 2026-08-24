import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import worker from "../src/index";
import { clearTables, ensureSchema } from "./schema";

beforeEach(async () => {
  await ensureSchema();
  await clearTables();
});

describe("scheduled — очистка счётчиков старше 7 суток (FR-018 фазы 007, research.md R10)", () => {
  it("удаляет записи старше порога и сохраняет свежие", async () => {
    await env.DB.prepare("INSERT INTO rate_limits (day, install_id, count) VALUES (?1, ?2, 1)")
      .bind("2026-01-01", "old-device")
      .run();
    await env.DB.prepare("INSERT INTO rate_limits (day, install_id, count) VALUES (?1, ?2, 1)")
      .bind("2026-08-23", "fresh-device")
      .run();
    await env.DB.prepare("INSERT INTO global_limits (day, model, count) VALUES (?1, ?2, 1)")
      .bind("2026-01-01", "gemini-3.5-flash-lite")
      .run();
    await env.DB.prepare("INSERT INTO global_limits (day, model, count) VALUES (?1, ?2, 1)")
      .bind("2026-08-23", "gemini-3.5-flash-lite")
      .run();

    await worker.scheduled(
      { cron: "0 3 * * *", scheduledTime: Date.parse("2026-08-23T03:00:00Z"), noRetry: () => {} } as never,
      env,
      { waitUntil: () => {}, passThroughOnException: () => {}, props: {} } as never,
    );

    const rateLimits = await env.DB.prepare("SELECT day FROM rate_limits").all<{ day: string }>();
    expect(rateLimits.results.map((r: { day: string }) => r.day)).toEqual(["2026-08-23"]);

    const globalLimits = await env.DB.prepare("SELECT day FROM global_limits").all<{ day: string }>();
    expect(globalLimits.results.map((r: { day: string }) => r.day)).toEqual(["2026-08-23"]);
  });
});
