// Signed GET URLs. RLS protects the row, never the object: authorisation of the
// file is decided here (vault: Ficheros-de-usuario-y-R2, rule 4).
// Exam audio and photos: public content in spirit, but until the bucket has its
// own CDN domain they are served with signed URLs too (kind "content", D-013).
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, requireAuthUser } from "../_shared/supabase.ts";
import { presign } from "../_shared/r2.ts";

// Reader audio carries the examiner voice (D-033): audio/{voice}/{level}/{exam}/{step}.mp3
const CONTENT_KEY = /^(audio\/[a-z]{2}_[a-z]+\/(B1|B2|C1)\/[a-z0-9-]+\/[a-z0-9-]+\.mp3|img\/(B1|B2|C1)\/[a-z0-9-]+\/[a-z0-9-]+\.webp)$/;

const Body = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("avatar"), userId: z.string().uuid() }),
  z.object({ kind: z.literal("recording"), sessionId: z.string().uuid() }),
  // Preloaded in the lobby: one call for every asset of the exam.
  z.object({ kind: z.literal("content"), keys: z.array(z.string().regex(CONTENT_KEY)).min(1).max(100) }),
]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const db = adminClient();
  if (b.kind === "content") {
    // Long enough to cover lobby + exam + feedback (~30 min) with margin.
    const urls = Object.fromEntries(await Promise.all(b.keys.map(async (k) => [k, await presign("GET", "content", k, 7200)])));
    return json({ urls, expiresIn: 7200 });
  }
  if (b.kind === "avatar") {
    const { data } = await db.from("profiles").select("avatar_key").eq("id", b.userId).maybeSingle();
    if (!data?.avatar_key) throw new HttpError(404, "not_found");
    return json({ url: await presign("GET", "media", data.avatar_key, 300), expiresIn: 300 });
  }
  const { data } = await db.from("exam_sessions")
    .select("user_a,user_b,recording_key,recording_expires_at").eq("id", b.sessionId).maybeSingle();
  if (!data || (data.user_a !== user.id && data.user_b !== user.id)) throw new HttpError(404, "not_found");
  if (!data.recording_key || new Date(data.recording_expires_at) < new Date()) throw new HttpError(410, "expired");
  return json({ url: await presign("GET", "recordings", data.recording_key, 3600), expiresIn: 3600 });
}));
