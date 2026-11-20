// Sign in with Apple token revocation (App Store guideline 5.1.1(v), D-062).
// When an Apple account is deleted, the app sends the one-time
// `authorizationCode` from a fresh Apple sign-in; we exchange it for a refresh
// token and revoke it, so the app disappears from the user's "Apps using Apple ID".
//
// Dependency-free: the client secret is an ES256 JWT signed with WebCrypto,
// whose ECDSA output (r||s) is already the JWS format.
//
// Secrets (Supabase project secrets): APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_PRIVATE_KEY (the .p8 contents), APPLE_CLIENT_ID (the bundle ID).

const APPLE = "https://appleid.apple.com";

export type AppleConfig = { teamId: string; keyId: string; privateKey: string; clientId: string };

export function appleConfig(): AppleConfig | null {
  const get = (k: string) => Deno.env.get(k)?.trim() ?? "";
  const c = { teamId: get("APPLE_TEAM_ID"), keyId: get("APPLE_KEY_ID"), privateKey: get("APPLE_PRIVATE_KEY"), clientId: get("APPLE_CLIENT_ID") };
  return c.teamId && c.keyId && c.privateKey && c.clientId ? c : null;
}

const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlJson = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));

/// PEM (with or without headers, with literal "\n" if pasted on one line) -> PKCS#8 bytes.
export function pemToPkcs8(pem: string): Uint8Array<ArrayBuffer> {
  const body = pem.replace(/\\n/g, "\n").replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/// Apple's client_secret: ES256 JWT, valid 5 minutes (max allowed is 6 months).
export async function appleClientSecret(c: AppleConfig, nowSec = Math.floor(Date.now() / 1000)): Promise<string> {
  const key = await crypto.subtle.importKey("pkcs8", pemToPkcs8(c.privateKey), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = b64urlJson({ alg: "ES256", kid: c.keyId, typ: "JWT" });
  const payload = b64urlJson({ iss: c.teamId, iat: nowSec, exp: nowSec + 300, aud: APPLE, sub: c.clientId });
  const input = `${header}.${payload}`;
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)));
  return `${input}.${b64url(sig)}`;
}

async function post(path: string, form: Record<string, string>, fetcher: typeof fetch): Promise<Response> {
  return await fetcher(`${APPLE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(form),
  });
}

/// Returns "revoked", or "skipped" when Apple is not configured. Throws on an
/// Apple error: the caller decides (deletion goes on, the error is reported).
export async function revokeAppleAuthorization(code: string, c: AppleConfig | null = appleConfig(), fetcher: typeof fetch = fetch): Promise<"revoked" | "skipped"> {
  if (!c) return "skipped";
  const secret = await appleClientSecret(c);
  const tok = await post("/auth/token", { client_id: c.clientId, client_secret: secret, code, grant_type: "authorization_code" }, fetcher);
  const body = await tok.json().catch(() => ({})) as { refresh_token?: string; access_token?: string; error?: string };
  if (!tok.ok) throw new Error(`apple_token_${body.error ?? tok.status}`);
  const token = body.refresh_token ?? body.access_token;
  if (!token) throw new Error("apple_token_missing");
  const rev = await post("/auth/revoke", {
    client_id: c.clientId,
    client_secret: secret,
    token,
    token_type_hint: body.refresh_token ? "refresh_token" : "access_token",
  }, fetcher);
  await rev.body?.cancel();
  if (!rev.ok) throw new Error(`apple_revoke_${rev.status}`);
  return "revoked";
}
