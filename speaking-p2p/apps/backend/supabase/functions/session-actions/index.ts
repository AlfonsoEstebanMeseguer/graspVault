// Everything a participant does inside an exam session.
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { env, requireAuthUser, rpc } from "../_shared/supabase.ts";
import { participantToken } from "../_shared/livekit.ts";
import { loadSession, tickAndApply } from "../_shared/session.ts";
import { Body } from "./schema.ts";

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const s = await loadSession(b.sessionId);
  if (!s || (s.user_a !== user.id && s.user_b !== user.id)) throw new HttpError(404, "not_found");
  const role = s.user_a === user.id ? "A" : "B";

  switch (b.action) {
    case "join": {
      if (s.state === "ended" || s.state === "aborted") throw new HttpError(410, "session_closed");
      await rpc("svc_session_presence", {
        p_session: b.sessionId,
        p_user: user.id,
        p_present: true,
        p_content_version: b.contentVersion ?? null,
      });
      const t = await tickAndApply(b.sessionId);
      const token = await participantToken(b.sessionId, user.id, { canPublish: t.mic[role] });
      return json({ token, url: env("LIVEKIT_URL"), role, tick: t });
    }
    case "flag": {
      await rpc("svc_session_set_flag", { p_session: b.sessionId, p_user: user.id, p_flag: b.flag, p_value: b.value });
      return json({ tick: await tickAndApply(b.sessionId) });
    }
    case "tick":
      return json({ tick: await tickAndApply(b.sessionId) });
    case "abort": {
      await rpc("svc_session_abort", { p_session: b.sessionId, p_user: user.id, p_reason: b.reason });
      return json({ tick: await tickAndApply(b.sessionId) });
    }
    case "control": {
      const c = b.control;
      const r = await rpc<{ version: number }>("svc_session_control", {
        p_session: b.sessionId,
        p_user: user.id,
        p_op: c.op,
        p_args: "args" in c ? c.args : {},
        p_expected_version: b.expectedVersion,
      });
      return json({ version: r.version, tick: await tickAndApply(b.sessionId) });
    }
    // Moderation evidence (D-051): stored, never acted on in phase 1.
    case "talk_stats": {
      const saved = await rpc<number>("svc_session_talk_stats", { p_session: b.sessionId, p_user: user.id, p_windows: b.windows });
      return json({ saved });
    }
    case "self_mute": {
      await rpc("svc_session_log", { p_session: b.sessionId, p_user: user.id, p_kind: "self_mute", p_data: { muted: b.muted } });
      return json({ ok: true });
    }
    case "skip": {
      await rpc("svc_session_debug_skip", { p_session: b.sessionId, p_user: user.id });
      return json({ tick: await tickAndApply(b.sessionId) });
    }
  }
}));
