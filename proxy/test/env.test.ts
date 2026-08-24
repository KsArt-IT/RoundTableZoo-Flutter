// Тест продовой конфигурации (US4, FR-031) — читает wrangler.toml как текст
// через Vite `?raw` (встраивается на этапе сборки теста, файловой системы в
// рантайме Workers нет), без парсера TOML — подключать его ради одного теста
// было бы зависимостью против R2.

import { describe, expect, it } from "vitest";
import toml from "../wrangler.toml?raw";

function section(toml: string, header: string): string {
  const start = toml.indexOf(header);
  if (start === -1) throw new Error(`секция ${header} не найдена`);
  const rest = toml.slice(start + header.length);
  const nextHeaderIdx = rest.search(/\n\[/);
  return rest.slice(0, nextHeaderIdx === -1 ? undefined : nextHeaderIdx);
}

describe("wrangler.toml — разделение контуров (research.md R11, FR-031)", () => {
  it("продовая секция не содержит ALLOW_UNVERIFIED_INTEGRITY", () => {
    const production = section(toml, "[env.production.vars]");
    expect(production).not.toContain("ALLOW_UNVERIFIED_INTEGRITY");
  });

  it("dev-секция содержит ALLOW_UNVERIFIED_INTEGRITY", () => {
    const dev = section(toml, "[env.dev.vars]");
    expect(dev).toContain("ALLOW_UNVERIFIED_INTEGRITY");
  });

  it("продовый и dev D1/KV не делят идентификаторы биндингов", () => {
    const devDb = section(toml, "[[env.dev.d1_databases]]");
    const prodDb = section(toml, "[[env.production.d1_databases]]");
    const devDbId = /database_id = "([^"]+)"/.exec(devDb)?.[1];
    const prodDbId = /database_id = "([^"]+)"/.exec(prodDb)?.[1];
    expect(devDbId).toBeDefined();
    expect(prodDbId).toBeDefined();
    expect(devDbId).not.toBe(prodDbId);

    const devKv = section(toml, "[[env.dev.kv_namespaces]]");
    const prodKv = section(toml, "[[env.production.kv_namespaces]]");
    const devKvId = /id = "([^"]+)"/.exec(devKv)?.[1];
    const prodKvId = /id = "([^"]+)"/.exec(prodKv)?.[1];
    expect(devKvId).toBeDefined();
    expect(prodKvId).toBeDefined();
    expect(devKvId).not.toBe(prodKvId);
  });

  it("продовая секция задаёт ENVIRONMENT = production", () => {
    const production = section(toml, "[env.production.vars]");
    expect(production).toContain('ENVIRONMENT = "production"');
  });
});
