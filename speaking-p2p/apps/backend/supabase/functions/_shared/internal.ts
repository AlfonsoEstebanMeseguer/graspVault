// Internal callers (pg_cron -> cron-worker, RevenueCat webhook): the function only
// knows the SHA-256 of the secret, compares in constant time and fails closed.
// Pattern `requireInternalCaller` from the vault (ADR 0011).
import { HttpError } from "./http.ts";

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function requireSecretHash(presented: string | null, expectedSha256Hex: string | undefined): Promise<void> {
  if (!expectedSha256Hex || !/^[0-9a-f]{64}$/.test(expectedSha256Hex)) {
    throw new HttpError(503, "not_configured"); // fail closed
  }
  if (!presented) throw new HttpError(401, "unauthenticated");
  if (!timingSafeEqual(await sha256Hex(presented), expectedSha256Hex)) throw new HttpError(401, "unauthenticated");
}
