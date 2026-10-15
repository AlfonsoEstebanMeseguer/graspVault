// Cloudflare R2 through presigned URLs. Bytes never cross an Edge Function;
// R2 credentials never reach the app (vault: Ficheros-de-usuario-y-R2).
// Traps from the vault: the endpoint does NOT include the bucket; EU buckets need
// the `.eu.` endpoint (otherwise every call is a 403, not NoSuchBucket).
import { AwsClient } from "npm:aws4fetch@1.0.20";
import { env } from "./supabase.ts";

let client: AwsClient | null = null;
function r2(): AwsClient {
  client ??= new AwsClient({
    accessKeyId: env("R2_ACCESS_KEY_ID"),
    secretAccessKey: env("R2_SECRET_ACCESS_KEY"),
    service: "s3",
    region: "auto",
  });
  return client;
}

function objectUrl(bucket: string, key: string): URL {
  const base = env("R2_ENDPOINT").replace(/\/$/, "");
  return new URL(`${base}/${bucket}/${key.split("/").map(encodeURIComponent).join("/")}`);
}

export async function presign(method: "GET" | "PUT", bucket: string, key: string, expiresSec: number, contentType?: string): Promise<string> {
  const url = objectUrl(bucket, key);
  url.searchParams.set("X-Amz-Expires", String(expiresSec));
  const signed = await r2().sign(new Request(url, {
    method,
    headers: contentType ? { "Content-Type": contentType } : undefined,
  }), { aws: { signQuery: true } });
  return signed.url;
}

export async function getObjectHead(bucket: string, key: string, bytes = 32): Promise<Uint8Array | null> {
  const res = await r2().fetch(objectUrl(bucket, key), { headers: { Range: `bytes=0-${bytes - 1}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`R2 GET ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
}

export async function deleteObject(bucket: string, key: string): Promise<void> {
  const res = await r2().fetch(objectUrl(bucket, key), { method: "DELETE" });
  if (!res.ok && res.status !== 404) throw new Error(`R2 DELETE ${res.status}`);
}

/// Magic bytes only, never decode (vault ADR 0013). WebP or JPEG.
export function sniffImage(head: Uint8Array): "webp" | "jpg" | null {
  if (head.length >= 12 && String.fromCharCode(...head.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...head.slice(8, 12)) === "WEBP") return "webp";
  if (head.length >= 3 && head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) return "jpg";
  return null;
}
