// Internal worker for the crons that need the outside world. Called only by
// pg_cron through pg_net with the dedicated token (see migrations/..._crons.sql).
// The token is checked by the database against Supabase Vault (D-021): nothing
// is copied by hand into this function's environment.
import { handler, HttpError, json } from "../_shared/http.ts";
import { adminClient, rpc } from "../_shared/supabase.ts";
import { tickAndApply } from "../_shared/session.ts";
import { deleteObject, kindForKey } from "../_shared/r2.ts";
import { sendPush } from "../_shared/push.ts";
import { analyticsEnabled, type AnalyticsEvent, captureBatch } from "../_shared/analytics.ts";

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
    .eq("status", "pending").lte("not_before", new Date().toISOString()).order("id").limit(200);
  let done = 0;
  for (const row of rows ?? []) {
    try {
      await deleteObject(kindForKey(row.object_key), row.object_key);
      await db.from("storage_gc_queue").update({ status: "done" }).eq("id", row.id);
      done++;
    } catch (e) {
      const attempts = row.attempts + 1;
      await db.from("storage_gc_queue").update({ attempts, last_error: String(e).slice(0, 500), status: attempts >= 8 ? "failed" : "pending" }).eq("id", row.id);
    }
  }
  return { done };
}

// analytics_outbox -> PostHog (D-063). One batch request per run; a failed batch
// is retried on the next minute, up to 5 times. Rows older than 7 days are
// dropped either way, so the table never grows while PostHog is not configured.
async function analytics() {
  const db = adminClient();
  const weekAgo = new Date(Date.now() - 7 * 86400_000).toISOString();
  await db.from("analytics_outbox").delete().lt("created_at", weekAgo);
  if (!analyticsEnabled()) return { skipped: "not_configured" };
  const { data: rows } = await db.from("analytics_outbox").select("id,user_id,event,properties,created_at,attempts")
    .lt("attempts", 5).order("id").limit(500);
  if (!rows?.length) return { sent: 0 };
  const ok = await captureBatch(rows.map((r) => ({
    event: r.event as AnalyticsEvent,
    distinctId: r.user_id,
    properties: r.properties,
    timestamp: r.created_at,
  })));
  const ids = rows.map((r) => r.id);
  if (ok) {
    await db.from("analytics_outbox").delete().in("id", ids);
    return { sent: ids.length };
  }
  for (const r of rows) await db.from("analytics_outbox").update({ attempts: r.attempts + 1 }).eq("id", r.id);
  return { sent: 0, failed: ids.length };
}

Deno.serve(handler(async (req) => {
  const token = req.headers.get("X-Internal-Token");
  if (!token || !(await rpc<boolean>("svc_verify_internal_token", { p_token: token }))) {
    throw new HttpError(401, "unauthenticated");
  }
  const { task } = await req.json().catch(() => ({ task: null }));
  switch (task) {
    case "sessions": return json(await sessions());
    case "outbox": return json(await outbox());
    case "storage_gc": return json(await storageGc());
    case "analytics": return json(await analytics());
    default: throw new HttpError(422, "unknown_task");
  }
}));
