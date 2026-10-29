// LiveKit -> presence (joined / left) for the 60 s reconnection grace, and the
// microphone being published / unpublished as moderation evidence (D-051).
// Webhook payloads are camelCase (the API answers snake_case: see livekit.ts).
import { json, preflight } from "../_shared/http.ts";
import { env, rpc } from "../_shared/supabase.ts";
import { verifyWebhook } from "../_shared/livekit.ts";
import { tickAndApply } from "../_shared/session.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  const raw = await req.text();
  if (!(await verifyWebhook(raw, req.headers.get("Authorization"), env("LIVEKIT_API_SECRET")))) {
    return json({ error: "unauthenticated" }, 401);
  }
  const ev = JSON.parse(raw) as {
    event: string;
    room?: { name?: string };
    participant?: { identity?: string };
    track?: { type?: string; source?: string };
  };
  const m = ev.room?.name?.match(/^exam_([0-9a-f-]{36})$/);
  const identity = ev.participant?.identity;
  if (m && identity && (ev.event === "track_published" || ev.event === "track_unpublished") && ev.track?.type === "AUDIO") {
    try {
      await rpc("svc_session_log", { p_session: m[1], p_user: identity, p_kind: ev.event, p_data: { source: ev.track.source ?? null } });
    } catch (e) {
      console.error("track log", e);
    }
    return json({ ok: true });
  }
  if (!m || !identity || !["participant_joined", "participant_left"].includes(ev.event)) return json({ ignored: true });
  try {
    await rpc("svc_session_presence", { p_session: m[1], p_user: identity, p_present: ev.event === "participant_joined" });
    await tickAndApply(m[1]);
  } catch (e) {
    console.error("presence", e);
  }
  return json({ ok: true });
});
