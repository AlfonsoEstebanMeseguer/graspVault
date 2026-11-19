// Right to erasure in PostHog (docs/legal/ASPECTOS_A_COMPLETAR.md §9, D-066):
// when an account is deleted, its person and its events are deleted there too.
// Uses the PRIVATE API (personal key with scope person:write), not the public
// capture key. Off until both secrets exist, like the rest of the telemetry:
//   POSTHOG_PERSONAL_API_KEY, POSTHOG_PROJECT_ID   (optional POSTHOG_APP_HOST,
//   default https://eu.posthog.com: the private API is NOT on eu.i.posthog.com).
// PostHog queues the event deletion and runs it in a weekly batch.

export type PersonDeleteRequest = { url: string; init: RequestInit };

export function personDeleteRequest(key: string, projectId: string, distinctId: string, appHost?: string): PersonDeleteRequest {
  const host = (appHost?.trim() || "https://eu.posthog.com").replace(/\/+$/, "");
  return {
    url: `${host}/api/projects/${encodeURIComponent(projectId)}/persons/bulk_delete/`,
    init: {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({ distinct_ids: [distinctId], delete_events: true }),
    },
  };
}

/// "skipped" when not configured; throws on an HTTP failure so the caller can report it.
export async function deletePosthogPerson(distinctId: string): Promise<"deleted" | "skipped"> {
  const key = Deno.env.get("POSTHOG_PERSONAL_API_KEY")?.trim();
  const project = Deno.env.get("POSTHOG_PROJECT_ID")?.trim();
  if (!key || !project) return "skipped";
  const { url, init } = personDeleteRequest(key, project, distinctId, Deno.env.get("POSTHOG_APP_HOST"));
  const res = await fetch(url, init);
  const text = await res.text().catch(() => "");
  if (!res.ok) throw new Error(`posthog person delete ${res.status}: ${text.slice(0, 200)}`);
  return "deleted";
}
