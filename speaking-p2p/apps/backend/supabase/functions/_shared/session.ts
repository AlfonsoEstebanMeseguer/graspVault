// Drives one exam session: SQL decides (svc_session_tick), this file applies the
// decision to LiveKit (mic permissions, hang up, recording). Called by the
// clients at every boundary and by cron-worker as a backstop.
import { adminClient, rpc } from "./supabase.ts";
import { applyMicPolicy, deleteRoom, startAudioEgress } from "./livekit.ts";

export type TickResult = {
  state: string;
  segment: number;
  mic: { A: boolean; B: boolean };
  needs_push: boolean;
  /// `${control_version}:${segment}`: the mic mark is keyed, so a jump BACK is pushed too (D-039).
  key: string;
  paused: boolean;
  server_now: string;
  abort_reason: string | null;
};

type SessionRow = {
  id: string;
  user_a: string | null;
  user_b: string | null;
  state: string;
  recording_consent_a: boolean;
  recording_consent_b: boolean;
  recording_key: string | null;
  feedback_ends_at: string | null;
};

export async function loadSession(id: string): Promise<SessionRow | null> {
  const { data, error } = await adminClient().from("exam_sessions")
    .select("id,user_a,user_b,state,recording_consent_a,recording_consent_b,recording_key,feedback_ends_at")
    .eq("id", id).maybeSingle();
  if (error) throw error;
  return data as SessionRow | null;
}

export async function tickAndApply(sessionId: string): Promise<TickResult> {
  const r = await rpc<TickResult>("svc_session_tick", { p_session: sessionId });
  if (!r.needs_push && r.state !== "ended" && r.state !== "aborted" && r.state !== "part1") return r;
  const s = await loadSession(sessionId);
  if (!s) return r;
  if (r.needs_push) {
    try {
      await applyMicPolicy(sessionId, s.user_a, s.user_b, r.mic);
      await rpc("svc_session_mark_applied_key", { p_session: sessionId, p_key: r.key });
    } catch (e) {
      // Not marked as applied: the next tick (client or cron) retries.
      console.error("mic push failed", sessionId, e);
    }
  }
  if (r.state === "ended" || r.state === "aborted") {
    await deleteRoom(sessionId).catch((e) => console.error("deleteRoom", e));
  }
  if (r.state === "part1" && s.recording_consent_a && s.recording_consent_b && !s.recording_key) {
    await maybeStartRecording(s);
  }
  return r;
}

async function maybeStartRecording(s: SessionRow) {
  const key = `recordings/${s.id}.ogg`;
  // Claim the slot first so two concurrent ticks never start two egresses.
  const expires = new Date(new Date(s.feedback_ends_at ?? Date.now()).getTime() + 30 * 86400_000).toISOString();
  const { data } = await adminClient().from("exam_sessions")
    .update({ recording_key: key, recording_expires_at: expires })
    .eq("id", s.id).is("recording_key", null).select("id");
  if (!data?.length) return;
  try {
    await startAudioEgress(s.id, key);
  } catch (e) {
    console.error("egress failed", s.id, e);
    await adminClient().from("exam_sessions").update({ recording_key: null, recording_expires_at: null }).eq("id", s.id);
  }
}
