// Cloudflare R2 through presigned URLs. Bytes never cross an Edge Function;
// R2 credentials never reach the app (vault: Ficheros-de-usuario-y-R2).
//
// One endpoint per bucket, WITH the bucket as the URL path (the project's naming):
//   R2_ENDPOINT_SPEAKING_MEDIA      = https://<account>.r2.cloudflarestorage.com/speaking-media
//   R2_ENDPOINT_SPEAKING_CONTENT    = .../speaking-content       (same credentials as media)
//   R2_ENDPOINT_SPEAKING_RECORDINGS = .../speaking-recordings    (its own token: it is handed to LiveKit Egress)
// The bucket name is read from the path, never from a separate variable, so the
// two cannot disagree. EU buckets need `.eu.` in the host (otherwise 403, not 404).
import { AwsClient } from "npm:aws4fetch@1.0.20";
import { env } from "./supabase.ts";

/// Server ceiling for avatars; the app compresses to 300 KB (avatar_image.dart maxAvatarBytes).
export const MAX_AVATAR_BYTES = 512 * 1024;

export type BucketKind = "media" | "content" | "recordings";

const ENDPOINT_VAR: Record<BucketKind, string> = {
  media: "R2_ENDPOINT_SPEAKING_MEDIA",
  content: "R2_ENDPOINT_SPEAKING_CONTENT",
  recordings: "R2_ENDPOINT_SPEAKING_RECORDINGS",
};
const CREDS_PREFIX: Record<BucketKind, string> = { media: "R2_MEDIA", content: "R2_MEDIA", recordings: "R2_RECORDINGS" };

export type BucketConfig = { origin: string; bucket: string; accessKeyId: string; secretAccessKey: string };

/// Parses `https://host/bucket` into origin + bucket. Exported for tests.
export function parseEndpoint(raw: string): { origin: string; bucket: string } {
  const url = new URL(raw.trim());
  const bucket = url.pathname.replace(/^\/+|\/+$/g, "");
  if (!bucket || bucket.includes("/")) throw new Error("R2 endpoint must be https://<host>/<bucket>");
  return { origin: url.origin, bucket };
}

export function bucketConfig(kind: BucketKind): BucketConfig {
  const { origin, bucket } = parseEndpoint(env(ENDPOINT_VAR[kind]));
  return {
    origin,
    bucket,
    accessKeyId: env(`${CREDS_PREFIX[kind]}_ACCESS_KEY`),
    secretAccessKey: env(`${CREDS_PREFIX[kind]}_SECRET_KEY`),
  };
}

const clients = new Map<BucketKind, { cfg: BucketConfig; client: AwsClient }>();
function r2(kind: BucketKind) {
  let c = clients.get(kind);
  if (!c) {
    const cfg = bucketConfig(kind);
    c = { cfg, client: new AwsClient({ accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey, service: "s3", region: "auto" }) };
    clients.set(kind, c);
  }
  return c;
}

function objectUrl(cfg: BucketConfig, key: string): URL {
  return new URL(`${cfg.origin}/${cfg.bucket}/${key.split("/").map(encodeURIComponent).join("/")}`);
}

/// For a PUT, Content-Type and Content-Length are bound into the signature, so
/// R2 refuses a body of another type or size. aws4fetch treats both headers as
/// "unsignable" unless `allHeaders` is set (security audit 2026-11, C6).
export async function presign(
  method: "GET" | "PUT",
  kind: BucketKind,
  key: string,
  expiresSec: number,
  contentType?: string,
  contentLength?: number,
): Promise<string> {
  const { cfg, client } = r2(kind);
  const url = objectUrl(cfg, key);
  url.searchParams.set("X-Amz-Expires", String(expiresSec));
  const headers: Record<string, string> = {};
  if (contentType) headers["Content-Type"] = contentType;
  if (contentLength !== undefined) headers["Content-Length"] = String(contentLength);
  const signed = await client.sign(new Request(url, { method, headers }), {
    aws: { signQuery: true, allHeaders: Object.keys(headers).length > 0 },
  });
  return signed.url;
}

export type ObjectHead = { head: Uint8Array; size: number | null };

/// First [bytes] of an object plus its total size (from Content-Range). Reads at
/// most [bytes] even if R2 ignores the Range header.
export async function getObjectHead(kind: BucketKind, key: string, bytes = 32): Promise<ObjectHead | null> {
  const { cfg, client } = r2(kind);
  const res = await client.fetch(objectUrl(cfg, key), { headers: { Range: `bytes=0-${bytes - 1}` } });
  if (res.status === 404) {
    await res.body?.cancel();
    return null;
  }
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`R2 GET ${res.status}`);
  }
  const range = res.headers.get("Content-Range")?.match(/\/(\d+)$/);
  const size = range ? Number(range[1]) : res.status === 200 ? Number(res.headers.get("Content-Length") ?? NaN) : NaN;
  const reader = res.body?.getReader();
  const out = new Uint8Array(bytes);
  let n = 0;
  while (reader && n < bytes) {
    const { done, value } = await reader.read();
    if (done) break;
    const take = Math.min(value.length, bytes - n);
    out.set(value.subarray(0, take), n);
    n += take;
  }
  await reader?.cancel();
  return { head: out.subarray(0, n), size: Number.isFinite(size) ? size : null };
}

export async function deleteObject(kind: BucketKind, key: string): Promise<void> {
  const { cfg, client } = r2(kind);
  const res = await client.fetch(objectUrl(cfg, key), { method: "DELETE" });
  await res.body?.cancel();
  if (!res.ok && res.status !== 404) throw new Error(`R2 DELETE ${res.status}`);
}

/// Which bucket an object key lives in (keys are prefixed by kind).
export function kindForKey(key: string): BucketKind {
  if (key.startsWith("recordings/")) return "recordings";
  if (key.startsWith("audio/") || key.startsWith("img/")) return "content";
  return "media";
}

/// Magic bytes only, never decode (vault ADR 0013). WebP or JPEG.
export function sniffImage(head: Uint8Array): "webp" | "jpg" | null {
  if (head.length >= 12 && String.fromCharCode(...head.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...head.slice(8, 12)) === "WEBP") return "webp";
  if (head.length >= 3 && head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) return "jpg";
  return null;
}
