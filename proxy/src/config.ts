// Чтение config:app и config:prompts из KV — data-model.md §1.3-1.4.
//
// config:app: отсутствие ключа -> дефолты (штатно, до первой записи конфига).
// config:prompts: отсутствие ключа -> ok:false — дефолта для текстов промпта
// нет и быть не может, это то же самое, что и битое хранилище (CHK020).
// В обоих случаях недоступность KV или непригодное для разбора значение -> ok:false,
// и вызывающая сторона обязана вернуть 500, а не подставить дефолт втихую.

import type { Env } from "./types";

export interface AppConfig {
  aiEnabled: boolean;
  models: string[];
  dailyCapOverride: number;
  perDeviceCapOverride: number;
}

export interface PersonaConfig {
  systemPrompt: string;
  anchors: string[];
  maxReplyLength: number;
}

export interface PromptsConfig {
  commonPrefix: string;
  personas: Record<string, PersonaConfig>;
}

export type ConfigResult<T> = { ok: true; value: T } | { ok: false };

const DEFAULT_APP_CONFIG: AppConfig = {
  aiEnabled: true,
  models: ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite"],
  dailyCapOverride: 400,
  perDeviceCapOverride: 15,
};

export async function readAppConfig(env: Env): Promise<ConfigResult<AppConfig>> {
  let raw: string | null;
  try {
    raw = await env.CONFIG.get("config:app");
  } catch {
    return { ok: false };
  }
  if (raw === null) return { ok: true, value: DEFAULT_APP_CONFIG };

  try {
    const parsed = JSON.parse(raw) as Partial<AppConfig>;
    if (!isValidAppConfig(parsed)) return { ok: false };
    return { ok: true, value: parsed };
  } catch {
    return { ok: false };
  }
}

function isValidAppConfig(value: Partial<AppConfig>): value is AppConfig {
  return (
    typeof value.aiEnabled === "boolean" &&
    Array.isArray(value.models) &&
    value.models.length > 0 &&
    value.models.every((m) => typeof m === "string" && m.length > 0) &&
    typeof value.dailyCapOverride === "number" &&
    value.dailyCapOverride > 0 &&
    typeof value.perDeviceCapOverride === "number" &&
    value.perDeviceCapOverride > 0
  );
}

export async function readPromptsConfig(env: Env): Promise<ConfigResult<PromptsConfig>> {
  let raw: string | null;
  try {
    raw = await env.CONFIG.get("config:prompts");
  } catch {
    return { ok: false };
  }
  if (raw === null) return { ok: false };

  try {
    const parsed = JSON.parse(raw) as Partial<PromptsConfig>;
    if (!isValidPromptsConfig(parsed)) return { ok: false };
    return { ok: true, value: parsed };
  } catch {
    return { ok: false };
  }
}

function isValidPromptsConfig(value: Partial<PromptsConfig>): value is PromptsConfig {
  if (typeof value.commonPrefix !== "string" || value.commonPrefix.length === 0) return false;
  if (typeof value.personas !== "object" || value.personas === null) return false;

  for (const persona of Object.values(value.personas)) {
    if (!isValidPersonaConfig(persona)) return false;
  }
  return true;
}

function isValidPersonaConfig(value: unknown): value is PersonaConfig {
  if (typeof value !== "object" || value === null) return false;
  const p = value as Partial<PersonaConfig>;
  return (
    typeof p.systemPrompt === "string" &&
    p.systemPrompt.length > 0 &&
    Array.isArray(p.anchors) &&
    p.anchors.length >= 6 &&
    p.anchors.every((a) => typeof a === "string" && a.length > 0) &&
    typeof p.maxReplyLength === "number" &&
    p.maxReplyLength > 0
  );
}
