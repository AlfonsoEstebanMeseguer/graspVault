// Everything a participant does inside an exam session.
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { env, requireAuthUser, rpc } from "../_shared/supabase.ts";
import { participantToken } from "../_shared/livekit.ts";
import { loadSession, tickAndApply } from "../_shared/session.ts";

const Id = z.string().uuid();
const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("join"), sessionId: Id }),
  z.object({ action: z.literal("flag"), sessionId: Id, flag: z.enum(["ready", "preloaded", "recording"]), value: z.boolean() }),
  z.object({ action: z.literal("tick"), sessionId: Id }),
  z.object({ action: z.literal("abort"), sessionId: Id, reason: z.enum(["left", "content_missing"]).default("left") }),
]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const s = await loadSession(b.sessionId);
  if (!s || (s.user_a !== user.id && s.user_b !== user.id)) throw new HttpError(404, "not_found");
  const role = s.user_a === user.id ? "A" : "B";

  switch (b.action) {
    case "join": {
      if (s.state === "ended" || s.state === "aborted") throw new HttpError(410, "session_closed");
      await rpc("svc_session_presence", { p_session: b.sessionId, p_user: user.id, p_present: true });
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
  }
}));
