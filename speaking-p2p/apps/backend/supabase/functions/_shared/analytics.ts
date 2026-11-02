// Product analytics (PostHog) for server-side events. Prepared, not yet turned
// on: a no-op until POSTHOG_API_KEY is set, so call sites can be added gradually
// and the key wired last (see docs/OBSERVABILITY.md and CLAUDE.md §11).
//
// Server-side capture keeps the events we trust (subscription state, matches,
// sessions) out of a tamperable client. Send a stable, non-PII distinct id (the
// user's uuid) and never event properties that carry personal content.

export type AnalyticsEvent =
  | "signup_completed"
  | "paywall_viewed"
  | "subscription_started"
  | "subscription_cancelled"
  | "matchmaking_matched"
  | "exam_part_started"
  | "exam_completed"
  | "exam_aborted"
  | "meeting_confirmed"
  | "meeting_no_show";

/// Fire-and-forget: analytics must never change behaviour and never throw.
export async function track(
  event: AnalyticsEvent,
  distinctId: string,
  properties: Record<string, string | number | boolean | null> = {},
): Promise<boolean> {
  const key = Deno.env.get("POSTHOG_API_KEY")?.trim();
  if (!key) return false; // not configured: no-op
  const host = (Deno.env.get("POSTHOG_HOST")?.trim() || "https://eu.i.posthog.com").replace(/\/+$/, "");
  try {
    const res = await fetch(`${host}/capture/`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: key,
        event,
        distinct_id: distinctId,
        properties: { ...properties, $lib: "mirlotalk-edge" },
        timestamp: new Date().toISOString(),
      }),
    });
    await res.body?.cancel();
    return res.ok;
  } catch {
    return false;
  }
}
