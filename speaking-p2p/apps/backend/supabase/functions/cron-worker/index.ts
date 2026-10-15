// Internal worker for the crons that need the outside world. Called only by
// pg_cron through pg_net with the dedicated token (see migrations/..._crons.sql).
import { handler, HttpError, json } from "../_shared/http.ts";
import { adminClient, env, rpc } from "../_shared/supabase.ts";
import { requireSecretHash } from "../_shared/internal.ts";
import { tickAndApply } from "../_shared/session.ts";
import { deleteObject } from "../_shared/r2.ts";
import { sendPush } from "../_shared/push.ts";

async function sessions() {
  const ids = await rpc<string[]>("svc_active_sessions", {});
  const results = await Promise.allSettled((ids ?? []).map((id) => tickAndApply(id)));
  return { ticked: results.length, failed: results.filter((r) => r.status === "rejected").length };
}

async function outbox() {
  const db = adminClient();
  const { data: rows } = await db.from("notification_outbox").select("id,user_id,kind,payload,attempts")
    .is("sent_at", null).lt("attempts", 5).order("id").limit(100);
  let sent = 0;
  for (const row of rows ?? []) {
    const { data: tokens } = await db.from("push_tokens").select("token,platform").eq("user_id", row.user_id);
    try {
      for (const t of tokens ?? []) await sendPush(t.token, row.kind, row.payload);
      await db.from("notification_outbox").update({ sent_at: new Date().toISOString() }).eq("id", row.id);
      sent++;
    } catch (e) {
      await db.from("notification_outbox").update({ attempts: row.attempts + 1, last_error: String(e).slice(0, 500) }).eq("id", row.id);
    }
  }
  return { sent };
}

// Never a terminal failure on the first error: retries, then `failed` for a human (vault media-gc).
async function storageGc() {
  const db = adminClient();
  const { data: rows } = await db.from("storage_gc_queue").select("id,object_key,attempts")
    .eq("status", "pending").order("id").limit(200);
  let done = 0;
  for (const row of rows ?? []) {
    const bucket = row.object_key.startsWith("recordings/") ? env("R2_RECORDINGS_BUCKET") : env("R2_MEDIA_BUCKET");
    try {
      await deleteObject(bucket, row.object_key);
      await db.from("storage_gc_queue").update({ status: "done" }).eq("id", row.id);
      done++;
    } catch (e) {
      const attempts = row.attempts + 1;
      await db.from("storage_gc_queue").update({ attempts, last_error: String(e).slice(0, 500), status: attempts >= 8 ? "failed" : "pending" }).eq("id", row.id);
    }
  }
  return { done };
}

Deno.serve(handler(async (req) => {
  await requireSecretHash(req.headers.get("X-Internal-Token"), Deno.env.get("INTERNAL_CRON_TOKEN_SHA256"));
  const { task } = await req.json().catch(() => ({ task: null }));
  switch (task) {
    case "sessions": return json(await sessions());
    case "outbox": return json(await outbox());
    case "storage_gc": return json(await storageGc());
    default: throw new HttpError(422, "unknown_task");
  }
}));
