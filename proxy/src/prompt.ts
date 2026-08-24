// Сборка промпта — research.md R15: общий префикс + персона + якорь.
// Якорь выбирается детерминированно и циклически, чем конструктивно
// обеспечивает FR-018 фазы 004 (повторный тап -> новый образ).

import type { PromptsConfig } from "./config";
import { dayOfYear } from "./day";

export interface BuiltPrompt {
  systemPrompt: string;
  maxReplyLength: number;
}

export function buildPrompt(
  prompts: PromptsConfig,
  characterId: string,
  attempt: number,
  now: Date,
): BuiltPrompt {
  const persona = prompts.personas[characterId];
  if (persona === undefined) {
    throw new Error(`buildPrompt: неизвестный characterId "${characterId}"`);
  }

  const anchor = pickAnchor(persona.anchors, attempt, now);

  const systemPrompt = [
    prompts.commonPrefix,
    persona.systemPrompt,
    anchorInstruction(anchor),
  ].join("\n\n");

  return { systemPrompt, maxReplyLength: persona.maxReplyLength };
}

export function pickAnchor(anchors: readonly string[], attempt: number, now: Date): string {
  const index = (dayOfYear(now) + attempt) % anchors.length;
  const anchor = anchors[index];
  if (anchor === undefined) throw new Error("pickAnchor: пустой список якорей");
  return anchor;
}

function anchorInstruction(anchor: string): string {
  return (
    `Образ этой реплики: ${anchor}. Оттолкнись именно от него — это твой источник ` +
    "сравнения на сейчас. Не подменяй его теми образами, которые кажутся тебе самыми " +
    "очевидными для твоего вида: они уже были. Если текст пользователя тяжёлый, образ " +
    "должен быть еле заметным или отсутствовать вовсе."
  );
}
