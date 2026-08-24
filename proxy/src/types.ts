// Типы контракта — contracts/react-api.md

export const REACTION_TONES = [
  "neutral",
  "warm",
  "playful",
  "dry",
  "sad",
  "encouraging",
] as const;

export type ReactionTone = (typeof REACTION_TONES)[number];

export interface ReactRequest {
  installId: string;
  characterId: string;
  moodScore: number;
  dayText: string;
  attempt: number;
  integrityToken?: string;
}

export interface ReactResponse {
  character: string;
  mood: ReactionTone;
  reply: string;
  intensity: number;
}

export type FailureCode =
  | "bad_request"
  | "integrity_failed"
  | "rate_limited"
  | "ai_disabled"
  | "invalid_ai_response"
  | "internal";

export interface ErrorResponse {
  error: FailureCode;
  scope?: "device" | "global";
  retryAfterSeconds?: number;
  message?: string;
}

export interface Env {
  DB: D1Database;
  CONFIG: KVNamespace;
  ENVIRONMENT: string;
  ALLOW_UNVERIFIED_INTEGRITY?: string;
  GEMINI_API_KEY: string;
  GCP_SA_KEY: string;
}
