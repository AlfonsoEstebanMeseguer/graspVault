// Agenda: offers, acceptances and the meeting card (CLAUDE.md §8).
import { z } from "npm:zod@3.23.8";
import { handler, json, parseBody } from "../_shared/http.ts";
import { requireAuthUser, rpc } from "../_shared/supabase.ts";

const Id = z.string().uuid();
const Level = z.enum(["B1", "B2", "C1"]);
const Instant = z.string().datetime({ offset: true });
const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("create_offer"), level: Level, windowStart: Instant, windowEnd: Instant }),
  z.object({ action: z.literal("cancel_offer"), offerId: Id }),
  z.object({ action: z.literal("accept"), offerId: Id, scheduledAt: Instant }),
  z.object({ action: z.literal("modify"), meetingId: Id, scheduledAt: Instant, level: Level }),
  z.object({ action: z.literal("confirm"), meetingId: Id }),
  z.object({ action: z.literal("cancel"), meetingId: Id }),
  z.object({ action: z.literal("enter"), meetingId: Id, contentVersion: z.number().int().min(1) }),
]);

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const u = user.id;
  switch (b.action) {
    case "create_offer":
      return json({ offerId: await rpc("svc_offer_create", { p_user: u, p_level: b.level, p_start: b.windowStart, p_end: b.windowEnd }) });
    case "cancel_offer":
      await rpc("svc_offer_cancel", { p_user: u, p_offer: b.offerId });
      return json({ ok: true });
    case "accept":
      return json(await rpc("svc_offer_accept", { p_user: u, p_offer: b.offerId, p_at: b.scheduledAt }));
    case "modify":
      await rpc("svc_meeting_modify", { p_user: u, p_meeting: b.meetingId, p_at: b.scheduledAt, p_level: b.level });
      return json({ ok: true });
    case "confirm":
      return json({ status: await rpc("svc_meeting_confirm", { p_user: u, p_meeting: b.meetingId }) });
    case "cancel":
      await rpc("svc_meeting_cancel", { p_user: u, p_meeting: b.meetingId });
      return json({ ok: true });
    case "enter":
      return json({ sessionId: await rpc("svc_meeting_enter", { p_user: u, p_meeting: b.meetingId, p_content_version: b.contentVersion }) });
  }
}));
