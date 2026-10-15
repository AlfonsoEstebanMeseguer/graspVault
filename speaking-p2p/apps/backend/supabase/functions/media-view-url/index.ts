// Signed GET URLs. RLS protects the row, never the object: authorisation of the
// file is decided here (vault: Ficheros-de-usuario-y-R2, rule 4).
// Exam audio and photos are NOT served here: they are static, public content
// behind the CDN domain (CONTENT_CDN_URL), see docs/DECISIONS.md D-013.
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, env, requireAuthUser } from "../_shared/supabase.ts";
import { presign } from "../_shared/r2.ts";

const Body = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("avatar"), userId: z.string().uuid() }),
  z.object({ kind: z.literal("recording"), sessionId: z.string().uuid() }),
]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const db = adminClient();
  if (b.kind === "avatar") {
    const { data } = await db.from("profiles").select("avatar_key").eq("id", b.userId).maybeSingle();
    if (!data?.avatar_key) throw new HttpError(404, "not_found");
    return json({ url: await presign("GET", env("R2_MEDIA_BUCKET"), data.avatar_key, 300), expiresIn: 300 });
  }
  const { data } = await db.from("exam_sessions")
    .select("user_a,user_b,recording_key,recording_expires_at").eq("id", b.sessionId).maybeSingle();
  if (!data || (data.user_a !== user.id && data.user_b !== user.id)) throw new HttpError(404, "not_found");
  if (!data.recording_key || new Date(data.recording_expires_at) < new Date()) throw new HttpError(410, "expired");
  return json({ url: await presign("GET", env("R2_RECORDINGS_BUCKET"), data.recording_key, 3600), expiresIn: 3600 });
}));
