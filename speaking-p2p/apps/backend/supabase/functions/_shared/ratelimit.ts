// Per-user fixed-window rate limit (security audit 2026-11, point 12): keeps one
// account from firing hundreds of calls at paths that cost money (LiveKit, R2).
// The counter lives in Postgres (svc_rate_hit), so it holds across isolates.
import { HttpError } from "./http.ts";
import { adminClient } from "./supabase.ts";

/// Generous ceilings: far above what the app does, low enough to cap a script.
export const LIMITS = {
  avatarUpload: { limit: 20, windowSec: 3600 },
  avatarConfirm: { limit: 40, windowSec: 3600 },
  mediaView: { limit: 600, windowSec: 3600 },
  sessionActions: { limit: 3600, windowSec: 3600 },
  meetingActions: { limit: 300, windowSec: 3600 },
  matchmaking: { limit: 1500, windowSec: 3600 },
  onboarding: { limit: 20, windowSec: 3600 },
  accountDelete: { limit: 10, windowSec: 3600 },
} as const;

export async function rateLimit(userId: string, bucket: keyof typeof LIMITS): Promise<void> {
  const { limit, windowSec } = LIMITS[bucket];
  const { data, error } = await adminClient().rpc("svc_rate_hit", {
    p_user: userId,
    p_bucket: bucket,
    p_limit: limit,
    p_window_sec: windowSec,
  });
  // A database error here means the request would fail further on anyway: do not
  // turn a transient error into a lockout, but log it.
  if (error) {
    console.error("rate limit check failed", bucket, error);
    return;
  }
  if (data !== true) throw new HttpError(429, "rate_limited");
}
