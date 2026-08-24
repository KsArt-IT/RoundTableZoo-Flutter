import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { incrementDeviceCount, incrementGlobalCount } from "../src/limits";
import { clearTables, ensureSchema } from "./schema";

beforeEach(async () => {
  await ensureSchema();
  await clearTables();
});

describe("incrementDeviceCount — атомарность на настоящем D1 (FR-013)", () => {
  it("параллельные инкременты с одного installId дают последовательные различные значения", async () => {
    const results = await Promise.all(
      Array.from({ length: 10 }, () => incrementDeviceCount(env, "2026-08-23", "device-a")),
    );
    const sorted = [...results].sort((a, b) => a - b);
    expect(sorted).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  it("разные installId ведут независимые счётчики", async () => {
    await incrementDeviceCount(env, "2026-08-23", "device-a");
    const first = await incrementDeviceCount(env, "2026-08-23", "device-b");
    expect(first).toBe(1);
  });
});

describe("incrementGlobalCount — раздельность по моделям (FR-012)", () => {
  it("параллельные инкременты с разных 'устройств' по одной модели не превышают итоговый предел", async () => {
    const results = await Promise.all(
      Array.from({ length: 5 }, () => incrementGlobalCount(env, "2026-08-23", "gemini-3.5-flash-lite")),
    );
    expect([...results].sort((a, b) => a - b)).toEqual([1, 2, 3, 4, 5]);
  });

  it("в global_limits по строке на модель, исчерпание одной не трогает другую", async () => {
    await incrementGlobalCount(env, "2026-08-23", "gemini-3.5-flash-lite");
    await incrementGlobalCount(env, "2026-08-23", "gemini-3.5-flash-lite");
    const fallbackFirst = await incrementGlobalCount(env, "2026-08-23", "gemini-3.1-flash-lite");
    expect(fallbackFirst).toBe(1);

    const rows = await env.DB.prepare(
      "SELECT model, count FROM global_limits WHERE day = ?1 ORDER BY model",
    )
      .bind("2026-08-23")
      .all<{ model: string; count: number }>();
    expect(rows.results).toEqual([
      { model: "gemini-3.1-flash-lite", count: 1 },
      { model: "gemini-3.5-flash-lite", count: 2 },
    ]);
  });
});
