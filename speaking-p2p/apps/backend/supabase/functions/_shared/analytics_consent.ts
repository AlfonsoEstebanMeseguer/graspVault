// Direct server events honour the Settings switch too (D-064): the outbox does it
// in SQL (private.analytics_emit); this is the same check for `track()` callers.
import { type AnalyticsEvent, analyticsEnabled, type Properties, track } from "./analytics.ts";
import { adminClient } from "./supabase.ts";

export async function trackUnlessOptedOut(event: AnalyticsEvent, userId: string, properties: Properties = {}): Promise<boolean> {
  if (!analyticsEnabled()) return false;
  const { data, error } = await adminClient().from("profiles_private").select("analytics_opt_out").eq("id", userId).maybeSingle();
  if (error || data?.analytics_opt_out) return false; // unknown = do not send
  return track(event, userId, properties);
}
