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

export async function presign(method: "GET" | "PUT", kind: BucketKind, key: string, expiresSec: number, contentType?: string): Promise<string> {
  const { cfg, client } = r2(kind);
  const url = objectUrl(cfg, key);
  url.searchParams.set("X-Amz-Expires", String(expiresSec));
  const signed = await client.sign(new Request(url, {
    method,
    headers: contentType ? { "Content-Type": contentType } : undefined,
  }), { aws: { signQuery: true } });
  return signed.url;
}

export async function getObjectHead(kind: BucketKind, key: string, bytes = 32): Promise<Uint8Array | null> {
  const { cfg, client } = r2(kind);
  const res = await client.fetch(objectUrl(cfg, key), { headers: { Range: `bytes=0-${bytes - 1}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`R2 GET ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
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
