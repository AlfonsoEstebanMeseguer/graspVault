// LiveKit without the server SDK (same approach as the vault): we sign the
// JWTs ourselves and call the Twirp API directly.
//
// Traps verified in the vault against the real server:
//  * UpdateParticipant REPLACES the whole permission: always send the full set,
//    or sending only can_publish=false also removes can_subscribe.
//  * The API answers in snake_case; webhooks arrive in camelCase. Fixtures must be
//    copied from REAL responses (see livekit_test.ts).
//  * For the server, reconnecting is leaving: nothing that changes permissions reconnects.
//  * Only a 404 means "not in the room".
import { env } from "./supabase.ts";
import { bucketConfig } from "./r2.ts";

const enc = new TextEncoder();
const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlJson = (v: unknown) => b64url(enc.encode(JSON.stringify(v)));

async function hmac(secret: string, data: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(data)));
}

export async function signJwt(claims: Record<string, unknown>, apiKey: string, apiSecret: string, ttlSec = 3600): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlJson({ alg: "HS256", typ: "JWT" });
  const payload = b64urlJson({ iss: apiKey, nbf: now - 5, exp: now + ttlSec, ...claims });
  return `${header}.${payload}.${b64url(await hmac(apiSecret, `${header}.${payload}`))}`;
}

export type Grants = { canPublish: boolean };

export const roomName = (sessionId: string) => `exam_${sessionId}`;

/// Participant token. canPublish reflects what the SERVER allows right now;
/// the client mirrors it, it never decides it (vault ADR 0033).
export function participantToken(sessionId: string, identity: string, grants: Grants): Promise<string> {
  return signJwt({
    sub: identity,
    video: {
      room: roomName(sessionId),
      roomJoin: true,
      canPublish: grants.canPublish,
      canPublishSources: ["microphone"], // audio only: no camera, no screen share
      canSubscribe: true,
      canPublishData: true,
    },
  }, env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"), 2 * 3600);
}

function apiBase(): string {
  return env("LIVEKIT_URL").replace(/^wss:/, "https:").replace(/^ws:/, "http:").replace(/\/$/, "");
}

async function twirp(service: string, method: string, body: unknown, video: Record<string, unknown>): Promise<Response> {
  const token = await signJwt({ video }, env("LIVEKIT_API_KEY"), env("LIVEKIT_API_SECRET"), 60);
  return fetch(`${apiBase()}/twirp/livekit.${service}/${method}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

/// Full permission set, snake_case, every time.
export function permissionBody(room: string, identity: string, canPublish: boolean) {
  return {
    room,
    identity,
    permission: { can_subscribe: true, can_publish: canPublish, can_publish_data: true, can_publish_sources: [2] /* MICROPHONE */ },
  };
}

/// Returns "ok" | "absent" (404: not in the room). Throws on anything else.
export async function setCanPublish(sessionId: string, identity: string, canPublish: boolean): Promise<"ok" | "absent"> {
  const room = roomName(sessionId);
  const res = await twirp("RoomService", "UpdateParticipant", permissionBody(room, identity, canPublish), { roomAdmin: true, room });
  if (res.status === 404) return "absent";
  if (!res.ok) throw new Error(`UpdateParticipant ${res.status}: ${await res.text()}`);
  await res.body?.cancel();
  return "ok";
}

/// Applies a mic policy: revoke first, then grant. A failure half-way leaves
/// LESS permission than due, never more (vault: lowering goes LiveKit -> DB first).
export async function applyMicPolicy(sessionId: string, a: string | null, b: string | null, mic: { A: boolean; B: boolean }) {
  const ops: Array<[string, boolean]> = [];
  if (a) ops.push([a, mic.A]);
  if (b) ops.push([b, mic.B]);
  ops.sort((x, y) => Number(x[1]) - Number(y[1])); // false (revoke) first
  for (const [identity, can] of ops) await setCanPublish(sessionId, identity, can);
}

export async function deleteRoom(sessionId: string): Promise<void> {
  const room = roomName(sessionId);
  const res = await twirp("RoomService", "DeleteRoom", { room }, { roomCreate: true });
  if (!res.ok && res.status !== 404) throw new Error(`DeleteRoom ${res.status}`);
  await res.body?.cancel();
}

/// Audio-only room recording into the R2 recordings bucket (lifecycle: 30 days).
export async function startAudioEgress(sessionId: string, objectKey: string): Promise<string> {
  const rec = bucketConfig("recordings");
  const res = await twirp("Egress", "StartRoomCompositeEgress", {
    room_name: roomName(sessionId),
    audio_only: true,
    file_outputs: [{
      file_type: 2, // OGG
      filepath: objectKey,
      s3: {
        access_key: rec.accessKeyId,
        secret: rec.secretAccessKey,
        endpoint: rec.origin,
        bucket: rec.bucket,
        region: "auto",
        force_path_style: true,
      },
    }],
  }, { roomRecord: true });
  if (!res.ok) throw new Error(`StartRoomCompositeEgress ${res.status}: ${await res.text()}`);
  const body = await res.json();
  return body.egress_id ?? body.egressId;
}

/// Webhook authenticity: the Authorization header is a JWT signed with the API
/// secret whose `sha256` claim is base64(sha256(raw body)).
export async function verifyWebhook(rawBody: string, authHeader: string | null, apiSecret: string): Promise<boolean> {
  if (!authHeader) return false;
  const token = authHeader.replace(/^Bearer /, "");
  const [h, p, s] = token.split(".");
  if (!h || !p || !s) return false;
  if (b64url(await hmac(apiSecret, `${h}.${p}`)) !== s) return false;
  let claims: { sha256?: string; exp?: number };
  try {
    claims = JSON.parse(atob(p.replace(/-/g, "+").replace(/_/g, "/")));
  } catch {
    return false;
  }
  if (claims.exp && claims.exp < Date.now() / 1000) return false;
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(rawBody)));
  return claims.sha256 === btoa(String.fromCharCode(...digest));
}
