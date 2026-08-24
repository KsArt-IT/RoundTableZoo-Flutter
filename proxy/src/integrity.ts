// Подтверждение подлинности — contracts/react-api.md §5, research.md R5.
// JWT RS256 (Web Crypto) -> access token Google -> decodeIntegrityToken.

import type { Env } from "./types";

const PACKAGE_NAME = "life.studyway.roundtablezoo";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const PLAY_INTEGRITY_SCOPE = "https://www.googleapis.com/auth/playintegrity";
const TOKEN_TTL_MS = 50 * 60 * 1000; // R5: 50 мин кэш при часе жизни токена
const TOKEN_CACHE_KEY = "gcp:token";

interface CachedToken {
  token: string;
  expiresAt: number;
}

interface ServiceAccountKey {
  client_email: string;
  private_key: string;
}

interface IntegrityVerdict {
  appIntegrity?: {
    appRecognitionVerdict?: string;
    packageName?: string;
  };
  deviceIntegrity?: {
    deviceRecognitionVerdict?: string[];
  };
}

export async function verifyIntegrity(env: Env, token: string | undefined): Promise<boolean> {
  if (!token) return false;

  let accessToken: string;
  try {
    accessToken = await getAccessToken(env);
  } catch {
    return false;
  }

  let response: Response;
  try {
    response = await fetch(
      `https://playintegrity.googleapis.com/v1/${PACKAGE_NAME}:decodeIntegrityToken`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ integrityToken: token }),
      },
    );
  } catch {
    return false;
  }
  if (!response.ok) return false;

  let payload: { tokenPayloadExternal?: IntegrityVerdict };
  try {
    payload = await response.json();
  } catch {
    return false;
  }

  return isVerdictAcceptable(payload.tokenPayloadExternal);
}

export function isVerdictAcceptable(verdict: IntegrityVerdict | undefined): boolean {
  if (!verdict) return false;
  const appOk =
    verdict.appIntegrity?.appRecognitionVerdict === "PLAY_RECOGNIZED" &&
    verdict.appIntegrity?.packageName === PACKAGE_NAME;
  const deviceOk =
    verdict.deviceIntegrity?.deviceRecognitionVerdict?.includes("MEETS_DEVICE_INTEGRITY") ?? false;
  return appOk && deviceOk;
}

async function getAccessToken(env: Env): Promise<string> {
  const cachedRaw = await env.CONFIG.get(TOKEN_CACHE_KEY);
  if (cachedRaw !== null) {
    try {
      const cached = JSON.parse(cachedRaw) as CachedToken;
      if (typeof cached.token === "string" && cached.expiresAt > Date.now()) {
        return cached.token;
      }
    } catch {
      // битый кэш — пойти за свежим токеном ниже
    }
  }

  const saKey = JSON.parse(env.GCP_SA_KEY) as ServiceAccountKey;
  const jwt = await signServiceAccountJwt(saKey);

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!response.ok) throw new Error("integrity: обмен JWT на access token не удался");

  const data = (await response.json()) as { access_token: string };
  const cached: CachedToken = { token: data.access_token, expiresAt: Date.now() + TOKEN_TTL_MS };
  await env.CONFIG.put(TOKEN_CACHE_KEY, JSON.stringify(cached));

  return data.access_token;
}

async function signServiceAccountJwt(saKey: ServiceAccountKey): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const issuedAt = Math.floor(Date.now() / 1000);
  const claims = {
    iss: saKey.client_email,
    scope: PLAY_INTEGRITY_SCOPE,
    aud: TOKEN_URL,
    iat: issuedAt,
    exp: issuedAt + 3600,
  };

  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(claims)}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(saKey.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  return `${signingInput}.${base64UrlBytes(new Uint8Array(signature))}`;
}

function base64UrlJson(value: unknown): string {
  return base64UrlBytes(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}
