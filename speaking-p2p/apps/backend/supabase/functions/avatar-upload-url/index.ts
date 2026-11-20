// Step 1 of the avatar flow (vault ADR 0010/0012): the SERVER picks the key and
// signs a PUT for exactly the declared content type.
import { z } from "npm:zod@3.23.8";
import { handler, json, parseBody } from "../_shared/http.ts";
import { requireAuthUser } from "../_shared/supabase.ts";
import { presign } from "../_shared/r2.ts";

const Body = z.object({ mimeType: z.enum(["image/webp", "image/jpeg"]) });

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const { mimeType } = await parseBody(req, Body);
  const ext = mimeType === "image/webp" ? "webp" : "jpg";
  const key = `avatars/${user.id}/${crypto.randomUUID()}.${ext}`;
  const url = await presign("PUT", "media", key, 300, mimeType);
  return json({ key, url, expiresIn: 300 });
}));
