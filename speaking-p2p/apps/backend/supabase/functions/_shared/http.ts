// HTTP plumbing shared by every function.
import { z } from "npm:zod@3.23.8";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/// Vault invariant 15: cut the CORS preflight BEFORE looking at the session.
/// An OPTIONS carries no Authorization; without this the browser aborts the POST.
export function preflight(req: Request): Response | null {
  return req.method === "OPTIONS" ? new Response("ok", { headers: corsHeaders }) : null;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export class HttpError extends Error {
  constructor(public status: number, public code: string) {
    super(code);
  }
}

/// Stable business error codes raised by the svc_* SQL functions (errcode P0001).
/// The app maps `code` to an i18n key; never show raw messages to users.
const STATUS_BY_CODE: Record<string, number> = {
  not_eligible: 402,
  already_onboarded: 409,
  username_taken: 409,
  already_accepted: 409,
  too_many_offers: 409,
  overlap: 409,
  offer_unavailable: 409,
  // Agenda v2 (D-046)
  slot_taken: 409,
  too_many_invites: 409,
  not_companion: 403,
  not_pending: 409,
  not_in_lobby: 409,
  not_confirmed: 409,
  too_early: 409,
  too_late: 410,
  partner_gone: 410,
  in_the_past: 422,
  bad_time: 422,
  bad_level: 422,
  bad_reason: 422,
  unknown_flag: 422,
  window_too_short: 422,
  window_out_of_range: 422,
  own_offer: 422,
  underage: 422,
  no_exam_available: 503,
  not_found: 404,
  session_not_found: 404,
  not_participant: 404,
  // Pro exam control (D-039)
  not_leader: 403,
  not_pro: 402,
  stale_control: 409,
  partner_not_pro: 409,
  content_missing_partner: 409,
  reader_speaking: 409,
  already_paused: 409,
  not_paused: 409,
  not_reader: 409,
  not_in_part: 409,
  not_in_exam: 409,
  not_started: 409,
  switching: 409,
  not_switching: 409,
  session_closed: 410,
  out_of_range: 422,
  bad_delta: 422,
  bad_op: 422,
  // Moderation evidence (D-051)
  bad_stats: 422,
  bad_kind: 422,
};

/// Turns a PostgREST/RPC error into an HttpError, or rethrows an unknown one as 500.
export function fromDbError(err: { message?: string; code?: string } | null): HttpError | null {
  if (!err) return null;
  const msg = err.message ?? "";
  if (msg in STATUS_BY_CODE) return new HttpError(STATUS_BY_CODE[msg], msg);
  if (msg.includes("underage")) return new HttpError(422, "underage");
  if (err.code === "23505") return new HttpError(409, "conflict");
  if (err.code === "23514") return new HttpError(422, "invalid");
  return new HttpError(500, "internal");
}

export async function parseBody<T extends z.ZodTypeAny>(req: Request, schema: T): Promise<z.infer<T>> {
  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    throw new HttpError(400, "bad_json");
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) throw new HttpError(422, "invalid_input");
  return parsed.data;
}

/// Wraps a handler: preflight, POST only, error mapping, never leaks internals.
export function handler(fn: (req: Request) => Promise<Response>): (req: Request) => Promise<Response> {
  return async (req) => {
    const pre = preflight(req);
    if (pre) return pre;
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    try {
      return await fn(req);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code }, e.status);
      console.error(e); // Sentry picks this up (see _shared/sentry.ts)
      return json({ error: "internal" }, 500);
    }
  };
}
