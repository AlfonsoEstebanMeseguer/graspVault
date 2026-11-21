// Step 1 of the avatar flow (vault ADR 0010/0012): the SERVER picks the key and
// signs a PUT for exactly the declared content type AND size (security audit
// 2026-11, C6). The key is queued for deletion one hour later; avatar-confirm
// cancels that, so an upload that is never confirmed does not stay in R2 (C8).
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, requireAuthUser } from "../_shared/supabase.ts";
import { MAX_AVATAR_BYTES, presign } from "../_shared/r2.ts";
import { rateLimit } from "../_shared/ratelimit.ts";

const Body = z.object({
  mimeType: z.enum(["image/webp", "image/jpeg"]),
  sizeBytes: z.number().int().min(1).max(MAX_AVATAR_BYTES),
});

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  await rateLimit(user.id, "avatarUpload");
  const { mimeType, sizeBytes } = await parseBody(req, Body);
  const ext = mimeType === "image/webp" ? "webp" : "jpg";
  const key = `avatars/${user.id}/${crypto.randomUUID()}.${ext}`;
  const { error } = await adminClient().from("storage_gc_queue").insert({
    object_key: key,
    reason: "avatar_unconfirmed",
    not_before: new Date(Date.now() + 3600_000).toISOString(),
  });
  if (error) throw new HttpError(500, "internal");
  const url = await presign("PUT", "media", key, 300, mimeType, sizeBytes);
  return json({ key, url, expiresIn: 300 });
}));
