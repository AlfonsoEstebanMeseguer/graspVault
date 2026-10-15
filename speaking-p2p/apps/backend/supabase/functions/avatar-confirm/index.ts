// Step 2: validate the BYTES (magic bytes, never decode — vault ADR 0013), then
// write the key. The trigger on profiles queues the previous object for deletion.
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, env, requireAuthUser } from "../_shared/supabase.ts";
import { deleteObject, getObjectHead, sniffImage } from "../_shared/r2.ts";

const Body = z.object({ key: z.string().max(200) });

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const { key } = await parseBody(req, Body);
  const m = key.match(/^avatars\/([0-9a-f-]{36})\/[0-9a-f-]{36}\.(webp|jpg)$/);
  if (!m || m[1] !== user.id) throw new HttpError(422, "invalid_key");
  const bucket = env("R2_MEDIA_BUCKET");
  const head = await getObjectHead(bucket, key);
  if (!head) throw new HttpError(404, "not_uploaded");
  if (sniffImage(head) !== m[2]) {
    await deleteObject(bucket, key);
    throw new HttpError(422, "invalid_image");
  }
  const { error } = await adminClient().from("profiles").update({ avatar_key: key }).eq("id", user.id);
  if (error) throw new HttpError(500, "internal");
  return json({ avatarKey: key });
}));
