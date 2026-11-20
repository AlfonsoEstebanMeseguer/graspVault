import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { type AppleConfig, appleClientSecret, revokeAppleAuthorization } from "./apple.ts";

async function testConfig(): Promise<{ config: AppleConfig; publicKey: CryptoKey }> {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]) as CryptoKeyPair;
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const b64 = btoa(String.fromCharCode(...der)).match(/.{1,64}/g)!.join("\n");
  // Pasted on one line with literal \n, as the dashboard often stores it.
  const pem = `-----BEGIN PRIVATE KEY-----\\n${b64.replace(/\n/g, "\\n")}\\n-----END PRIVATE KEY-----`;
  return { config: { teamId: "TEAM123456", keyId: "KEY1234567", privateKey: pem, clientId: "com.speakingp2p.speakingP2p" }, publicKey: pair.publicKey };
}

const decode = (s: string) => JSON.parse(atob(s.replace(/-/g, "+").replace(/_/g, "/")));

Deno.test("apple: el client_secret es un ES256 válido con iss/sub/aud de Apple y 5 min de vida", async () => {
  const { config, publicKey } = await testConfig();
  const jwt = await appleClientSecret(config, 1_000_000);
  const [h, p, s] = jwt.split(".");
  assertEquals(decode(h), { alg: "ES256", kid: "KEY1234567", typ: "JWT" });
  assertEquals(decode(p), { iss: "TEAM123456", iat: 1_000_000, exp: 1_000_300, aud: "https://appleid.apple.com", sub: "com.speakingp2p.speakingP2p" });
  const sig = Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, sig, new TextEncoder().encode(`${h}.${p}`));
  assertEquals(ok, true);
});

Deno.test("apple: canjea el código y revoca el refresh token", async () => {
  const { config } = await testConfig();
  const calls: Array<{ url: string; form: URLSearchParams }> = [];
  const fake = (async (url: string, init: RequestInit) => {
    const form = init.body as URLSearchParams;
    calls.push({ url, form });
    if (url.endsWith("/auth/token")) return new Response(JSON.stringify({ refresh_token: "r1", access_token: "a1" }), { status: 200 });
    return new Response("", { status: 200 });
  }) as unknown as typeof fetch;
  assertEquals(await revokeAppleAuthorization("code-1", config, fake), "revoked");
  assertEquals(calls.map((c) => c.url), ["https://appleid.apple.com/auth/token", "https://appleid.apple.com/auth/revoke"]);
  assertEquals(calls[0].form.get("code"), "code-1");
  assertEquals(calls[0].form.get("grant_type"), "authorization_code");
  assertEquals(calls[1].form.get("token"), "r1");
  assertEquals(calls[1].form.get("token_type_hint"), "refresh_token");
});

Deno.test("apple: sin secretos no hace nada; un error de Apple se lanza para reportarlo", async () => {
  assertEquals(await revokeAppleAuthorization("x", null), "skipped");
  const { config } = await testConfig();
  const failing = (async () => new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 })) as unknown as typeof fetch;
  await assertRejects(() => revokeAppleAuthorization("x", config, failing), Error, "apple_token_invalid_grant");
});
