// Live matchmaking. The client calls `enqueue` every ~10 s while the search
// screen is open (heartbeat); a missing heartbeat for 25 s drops the user.
import { z } from "npm:zod@3.23.8";
import { handler, json, parseBody } from "../_shared/http.ts";
import { requireAuthUser, rpc } from "../_shared/supabase.ts";

const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("enqueue"), level: z.enum(["B1", "B2", "C1"]), contentVersion: z.number().int().min(1) }),
  z.object({ action: z.literal("cancel") }),
]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  if (b.action === "cancel") {
    await rpc("svc_match_cancel", { p_user: user.id });
    return json({ status: "cancelled" });
  }
  const r = await rpc<{ status: string; session_id?: string }>("svc_match_enqueue", {
    p_user: user.id, p_level: b.level, p_content_version: b.contentVersion,
  });
  // For the 15 s prompt: only offered when the user has no open meeting.
  const hasOpenMeeting = r.status === "queued" ? await rpc<boolean>("svc_has_open_meeting", { p_user: user.id }) : false;
  return json({ ...r, hasOpenMeeting });
}));
