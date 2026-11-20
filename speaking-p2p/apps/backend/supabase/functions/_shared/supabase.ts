// Supabase clients. The service_role key never leaves the backend.
import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2.45.4";
import { HttpError, fromDbError } from "./http.ts";

/// Values are always trimmed: a trailing newline pasted into a secret breaks
/// request signing with an opaque "invalid header" (it happened, see PROGRESS).
export function env(name: string): string {
  const v = Deno.env.get(name)?.trim();
  if (!v) throw new Error(`missing env ${name}`);
  return v;
}

let admin: SupabaseClient | null = null;
export function adminClient(): SupabaseClient {
  admin ??= createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return admin;
}

/// iat = when this access token was issued (a refresh mints a new one).
/// authTime = when the user last really signed in: the newest amr[].timestamp,
/// which a token refresh keeps (security audit 2026-11, C10). 0 if absent.
export type AuthContext = { user: User; jwt: string; iat: number; authTime: number };

/// Verifies the caller's JWT against Supabase Auth (not just decoding it).
export async function requireAuthUser(req: Request): Promise<AuthContext> {
  const header = req.headers.get("Authorization") ?? "";
  const jwt = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!jwt) throw new HttpError(401, "unauthenticated");
  const { data, error } = await adminClient().auth.getUser(jwt);
  if (error || !data.user) throw new HttpError(401, "unauthenticated");
  let iat = 0;
  let authTime = 0;
  try {
    // Decoded only AFTER getUser verified this exact token.
    const claims = JSON.parse(atob(jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    iat = claims.iat ?? 0;
    const amr: unknown[] = Array.isArray(claims.amr) ? claims.amr : [];
    authTime = Math.max(0, ...amr.map((a) => {
      const t = (a as { timestamp?: unknown } | null)?.timestamp;
      return typeof t === "number" ? t : 0;
    }));
  } catch { /* both stay 0: treated as an old session */ }
  return { user: data.user, jwt, iat, authTime };
}

/// Calls a svc_* function with the service role and maps business errors.
export async function rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await adminClient().rpc(fn, args);
  const mapped = fromDbError(error);
  if (mapped) {
    if (mapped.status === 500) console.error(`rpc ${fn} failed`, error);
    throw mapped;
  }
  return data as T;
}
