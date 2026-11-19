// Product analytics (PostHog) for server-side events (D-061, D-063). A no-op
// until POSTHOG_API_KEY is set (see docs/OBSERVABILITY.md and CLAUDE.md §11).
//
// Server-side capture keeps the events we trust (subscription state, matches,
// sessions) out of a tamperable client. Two paths:
//   * direct `track()` from the Edge Function that owns the fact (signup, RevenueCat);
//   * the `analytics_outbox` table, written by triggers in the same transaction as
//     the fact (exam states, matches, meetings) and drained by cron-worker.
// The distinct id is the user's uuid; never properties that carry personal content.

export type AnalyticsEvent =
  // direct
  | "signup_completed"
  | "subscription_started"
  | "subscription_cancelled"
  // outbox (migration 20261119120000_analytics_outbox.sql)
  | "matchmaking_matched"
  | "exam_lobby_entered"
  | "exam_part_started"
  | "exam_completed"
  | "exam_aborted"
  | "meeting_offer_created"
  | "meeting_accepted"
  | "meeting_confirmed"
  | "meeting_no_show";

export type Properties = Record<string, string | number | boolean | null>;

export type CaptureEvent = {
  event: AnalyticsEvent;
  distinctId: string;
  properties?: Properties;
  /// When the fact happened (the outbox row's created_at); defaults to now.
  timestamp?: string;
};

export function analyticsEnabled(): boolean {
  return !!Deno.env.get("POSTHOG_API_KEY")?.trim();
}

function host(): string {
  return (Deno.env.get("POSTHOG_HOST")?.trim() || "https://eu.i.posthog.com").replace(/\/+$/, "");
}

export type BatchBody = {
  api_key: string;
  batch: { event: AnalyticsEvent; distinct_id: string; properties: Properties; timestamp: string }[];
};

/// PostHog's batch body. `$geoip_disable`: the request comes from Supabase's
/// servers, so a GeoIP lookup would only stamp the data centre's city on everyone.
export function toBatchBody(key: string, events: CaptureEvent[], now = new Date()): BatchBody {
  return {
    api_key: key,
    batch: events.map((e) => ({
      event: e.event,
      distinct_id: e.distinctId,
      properties: { ...(e.properties ?? {}), $lib: "mirlotalk-edge", $geoip_disable: true },
      timestamp: e.timestamp ?? now.toISOString(),
    })),
  };
}

/// Sends several events in one request. Never throws: returns false when not
/// configured or when PostHog did not accept them (the caller may retry).
export async function captureBatch(events: CaptureEvent[]): Promise<boolean> {
  const key = Deno.env.get("POSTHOG_API_KEY")?.trim();
  if (!key || events.length === 0) return false;
  try {
    const res = await fetch(`${host()}/batch/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(toBatchBody(key, events)),
    });
    await res.body?.cancel();
    return res.ok;
  } catch {
    return false;
  }
}

/// One event. Analytics must never change behaviour and never throw.
export function track(event: AnalyticsEvent, distinctId: string, properties: Properties = {}): Promise<boolean> {
  return captureBatch([{ event, distinctId, properties }]);
}
