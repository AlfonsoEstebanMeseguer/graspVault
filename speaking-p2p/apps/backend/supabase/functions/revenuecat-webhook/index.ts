// RevenueCat -> entitlements. Idempotent per event id; out-of-order events ignored.
// The app identifies with Purchases.logIn(supabaseUserId), so app_user_id is our uuid.
import { handler, HttpError, json } from "../_shared/http.ts";
import { rpc } from "../_shared/supabase.ts";
import { requireSecretHash } from "../_shared/internal.ts";
import { mapRcEvent, type RcEvent } from "../_shared/revenuecat.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

Deno.serve(handler(async (req) => {
  await requireSecretHash(req.headers.get("Authorization"), Deno.env.get("REVENUECAT_WEBHOOK_AUTH_SHA256"));
  const body = await req.json().catch(() => null) as { event?: RcEvent } | null;
  const e = body?.event;
  if (!e?.id || !e.type) throw new HttpError(422, "invalid_input");
  const mapped = mapRcEvent(e);
  if (!mapped || !UUID.test(e.app_user_id)) return json({ ignored: true });
  const applied = await rpc<boolean>("svc_apply_rc_event", {
    p_event_id: e.id,
    p_user: e.app_user_id,
    p_status: mapped.status,
    p_period_end: mapped.periodEnd?.toISOString() ?? null,
    p_event_at: new Date(e.event_timestamp_ms).toISOString(),
    p_plan: mapped.plan,
  });
  return json({ applied });
}));
