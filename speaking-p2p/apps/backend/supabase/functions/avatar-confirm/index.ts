// Step 2: validate the BYTES (magic bytes, never decode — vault ADR 0013) and the
// size (security audit 2026-11, C6), then write the key. The trigger on profiles
// queues the previous object for deletion; the pending "unconfirmed" deletion of
// this key (C8) and any older queued deletion of it are cancelled.
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, requireAuthUser } from "../_shared/supabase.ts";
import { deleteObject, getObjectHead, MAX_AVATAR_BYTES, sniffImage } from "../_shared/r2.ts";
import { rateLimit } from "../_shared/ratelimit.ts";

// `remove` drops the photo (back to the initial); the same trigger queues the
// old object for deletion.
const Body = z.union([z.object({ key: z.string().max(200) }), z.object({ remove: z.literal(true) })]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  await rateLimit(user.id, "avatarConfirm");
  const body = await parseBody(req, Body);
  const db = adminClient();
  if ("remove" in body) {
    const { error } = await db.from("profiles").update({ avatar_key: null }).eq("id", user.id);
    if (error) throw new HttpError(500, "internal");
    return json({ avatarKey: null });
  }
  const { key } = body;
  const m = key.match(/^avatars\/([0-9a-f-]{36})\/[0-9a-f-]{36}\.(webp|jpg)$/);
  if (!m || m[1] !== user.id) throw new HttpError(422, "invalid_key");
  const obj = await getObjectHead("media", key);
  if (!obj) throw new HttpError(404, "not_uploaded");
  if (obj.size === null || obj.size > MAX_AVATAR_BYTES) {
    await deleteObject("media", key);
    throw new HttpError(422, "too_large");
  }
  if (sniffImage(obj.head) !== m[2]) {
    await deleteObject("media", key);
    throw new HttpError(422, "invalid_image");
  }
  const { error } = await db.from("profiles").update({ avatar_key: key }).eq("id", user.id);
  if (error) throw new HttpError(500, "internal");
  // The object is now in use: no queued deletion may remove it.
  await db.from("storage_gc_queue").delete().eq("object_key", key).eq("status", "pending");
  return json({ avatarKey: key });
}));
