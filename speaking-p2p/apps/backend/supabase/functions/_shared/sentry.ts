// Error reporting for the Edge Functions. Prepared, not yet turned on: it is a
// no-op until SENTRY_DSN_FUNCTIONS is set in the project secrets, so it is safe
// to call from everywhere now and wire the real DSN last (see docs/OBSERVABILITY.md).
//
// Dependency-free on purpose: it parses the DSN and POSTs a minimal event to the
// Sentry Store API with fetch. No PII is sent — only the error name, message and
// stack. Never pass user content here.

type DsnParts = { host: string; projectId: string; publicKey: string };

function parseDsn(dsn: string): DsnParts | null {
  try {
    const u = new URL(dsn);
    const projectId = u.pathname.replace(/^\/+/, "");
    if (!u.username || !projectId) return null;
    return { host: u.host, projectId, publicKey: u.username };
  } catch {
    return null;
  }
}

/// Fire-and-forget: reporting must never change the response the user gets, and
/// a failure in Sentry itself must never throw. Returns true if an event was sent.
export async function captureException(err: unknown, context?: Record<string, unknown>): Promise<boolean> {
  const dsn = Deno.env.get("SENTRY_DSN_FUNCTIONS")?.trim();
  if (!dsn) return false; // not configured: no-op
  const parts = parseDsn(dsn);
  if (!parts) return false;

  const e = err instanceof Error ? err : new Error(String(err));
  const event = {
    event_id: crypto.randomUUID().replace(/-/g, ""),
    timestamp: new Date().toISOString(),
    platform: "javascript",
    level: "error",
    environment: Deno.env.get("SENTRY_ENVIRONMENT")?.trim() || "production",
    server_name: context?.fn ? String(context.fn) : undefined,
    exception: { values: [{ type: e.name, value: e.message, stacktrace: { frames: framesFrom(e) } }] },
    extra: context,
  };

  const url = `https://${parts.host}/api/${parts.projectId}/store/`;
  const auth = `Sentry sentry_version=7, sentry_key=${parts.publicKey}, sentry_client=mirlotalk-edge/1.0`;
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Sentry-Auth": auth },
      body: JSON.stringify(event),
    });
    // Drain the body so the connection can be reused and not leak.
    await res.body?.cancel();
    return res.ok;
  } catch {
    return false; // network error talking to Sentry: swallow
  }
}

function framesFrom(e: Error): Array<{ filename: string; function: string }> {
  const lines = (e.stack ?? "").split("\n").slice(1, 21);
  return lines.map((l) => ({ filename: l.trim(), function: "" }));
}
