// Work that must outlive the response (error reports, analytics). On Supabase
// Edge a plain `void promise` may be killed as soon as the response is sent;
// EdgeRuntime.waitUntil keeps the worker alive until it settles. Elsewhere
// (deno test, local) it just runs detached. Never throws.
type EdgeRuntimeLike = { waitUntil?: (p: Promise<unknown>) => void };

export function inBackground(p: Promise<unknown>): void {
  const safe = p.catch(() => {});
  const rt = (globalThis as { EdgeRuntime?: EdgeRuntimeLike }).EdgeRuntime;
  if (rt?.waitUntil) rt.waitUntil(safe);
}
