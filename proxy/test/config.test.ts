import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { readAppConfig, readPromptsConfig } from "../src/config";

const VALID_PROMPTS = {
  commonPrefix: "правила",
  personas: {
    hippo: {
      systemPrompt: "бегемот",
      anchors: ["a1", "a2", "a3", "a4", "a5", "a6"],
      maxReplyLength: 220,
    },
  },
};

describe("readAppConfig", () => {
  beforeEach(async () => {
    await env.CONFIG.delete("config:app");
  });

  it("отсутствие ключа даёт дефолты из data-model.md §1.3", async () => {
    const result = await readAppConfig(env);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.aiEnabled).toBe(true);
      expect(result.value.models).toEqual(["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"]);
      expect(result.value.dailyCapOverride).toBe(400);
      expect(result.value.perDeviceCapOverride).toBe(15);
    }
  });

  it("читает валидное значение из KV", async () => {
    await env.CONFIG.put(
      "config:app",
      JSON.stringify({ aiEnabled: false, models: ["m1"], dailyCapOverride: 5, perDeviceCapOverride: 2 }),
    );
    const result = await readAppConfig(env);
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.value.aiEnabled).toBe(false);
  });

  it("непригодный JSON даёт ok:false (=> 500, не дефолт)", async () => {
    await env.CONFIG.put("config:app", "{не json");
    const result = await readAppConfig(env);
    expect(result.ok).toBe(false);
  });

  it("значение с нарушенной формой даёт ok:false", async () => {
    await env.CONFIG.put("config:app", JSON.stringify({ aiEnabled: "yes" }));
    const result = await readAppConfig(env);
    expect(result.ok).toBe(false);
  });

  it("пустой список models даёт ok:false", async () => {
    await env.CONFIG.put(
      "config:app",
      JSON.stringify({ aiEnabled: true, models: [], dailyCapOverride: 5, perDeviceCapOverride: 2 }),
    );
    expect((await readAppConfig(env)).ok).toBe(false);
  });
});

describe("readPromptsConfig", () => {
  beforeEach(async () => {
    await env.CONFIG.delete("config:prompts");
  });

  it("отсутствие ключа даёт ok:false — дефолта для текстов промпта нет (CHK020)", async () => {
    const result = await readPromptsConfig(env);
    expect(result.ok).toBe(false);
  });

  it("читает валидный конфиг", async () => {
    await env.CONFIG.put("config:prompts", JSON.stringify(VALID_PROMPTS));
    const result = await readPromptsConfig(env);
    expect(result.ok).toBe(true);
    if (result.ok) expect(Object.keys(result.value.personas)).toContain("hippo");
  });

  it("персонаж с < 6 якорей отклоняется", async () => {
    const broken = {
      ...VALID_PROMPTS,
      personas: { hippo: { ...VALID_PROMPTS.personas.hippo, anchors: ["a1", "a2"] } },
    };
    await env.CONFIG.put("config:prompts", JSON.stringify(broken));
    expect((await readPromptsConfig(env)).ok).toBe(false);
  });

  it("непригодный JSON даёт ok:false", async () => {
    await env.CONFIG.put("config:prompts", "не json");
    expect((await readPromptsConfig(env)).ok).toBe(false);
  });
});
