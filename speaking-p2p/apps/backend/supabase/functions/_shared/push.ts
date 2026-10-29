// FCM HTTP v1 (Android + iOS through APNs in Firebase). If the service account
// is not configured the push is skipped loudly, not silently (PROGRESS.md: stub).

type ServiceAccount = { client_email: string; private_key: string; project_id: string };
let cached: { token: string; exp: number } | null = null;

function pemToPkcs8(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)).buffer;
}
const b64url = (s: string | Uint8Array) =>
  btoa(typeof s === "string" ? s : String.fromCharCode(...s)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp > now + 60) return cached.token;
  const head = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey("pkcs8", pemToPkcs8(sa.private_key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claims}`)));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${head}.${claims}.${b64url(sig)}` }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}`);
  const body = await res.json();
  cached = { token: body.access_token, exp: now + body.expires_in };
  return cached.token;
}

/// The text is localised ON THE DEVICE from `kind` (loc-key), never composed here.
export async function sendPush(token: string, kind: string, payload: Record<string, unknown>): Promise<void> {
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) throw new Error("push not configured (FCM_SERVICE_ACCOUNT_JSON)");
  const sa = JSON.parse(raw) as ServiceAccount;
  const data = Object.fromEntries(Object.entries({ kind, ...payload }).map(([k, v]) => [k, String(v)]));
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await accessToken(sa)}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        data,
        android: { notification: { title_loc_key: `push_${kind}_title`, body_loc_key: `push_${kind}_body` } },
        apns: { payload: { aps: { alert: { "title-loc-key": `push_${kind}_title`, "loc-key": `push_${kind}_body` } } } },
      },
    }),
  });
  if (res.status === 404) return; // token unregistered: nothing to deliver
  if (!res.ok) throw new Error(`fcm ${res.status}`);
}
