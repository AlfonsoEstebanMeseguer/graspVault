// Exam timeline: turns an Exam into a flat, deterministic list of segments
// relative to the instant Part 1 starts. The server stores this schedule in
// exam_sessions.schedule when the exam starts, and every client derives "what
// is happening now" from (serverNow - exam_started_at). There is no
// independent local stopwatch (CLAUDE.md §6).
//
// Each step becomes up to two segments:
//   reader: the examiner audio plays, both microphones are closed
//   speak:  the speaking window; mic policy depends on the step kind
// The Dart client mirrors this algorithm (apps/mobile/lib/domain/exam/timeline.dart)
// and both test suites run the same golden fixture (content/fixtures/timeline-golden.json).
import type { Exam, Step } from "./schema.ts";

/// Silence after the reader audio before the speaking window opens.
export const READER_GAP_MS = 600;
export const FEEDBACK_MS = 5 * 60_000;
export const LOBBY_MS = 5 * 60_000;

export type Mic = { A: boolean; B: boolean };
export type Phase = "reader" | "speak";

export type Segment = {
  index: number;
  part: 1 | 2 | 3 | 4;
  stepId: string;
  kind: Step["kind"];
  phase: Phase;
  target: "A" | "B" | "both" | null;
  startMs: number;
  endMs: number;
  mic: Mic;
};

export type Timeline = {
  segments: Segment[];
  totalMs: number;
};

const MUTED: Mic = { A: false, B: false };

export function micFor(step: Step, phase: Phase): Mic {
  if (phase === "reader" || step.kind === "narration") return MUTED;
  if (step.kind === "turn") return { A: step.target === "A", B: step.target === "B" };
  return { A: true, B: true }; // open: both talk, whoever the question is for
}

export function buildTimeline(exam: Exam): Timeline {
  const segments: Segment[] = [];
  let t = 0;
  const push = (part: Segment["part"], step: Step, phase: Phase, durationMs: number) => {
    if (durationMs <= 0) return;
    segments.push({
      index: segments.length,
      part,
      stepId: step.id,
      kind: step.kind,
      phase,
      target: step.kind === "narration" ? null : step.target,
      startMs: t,
      endMs: t + durationMs,
      mic: micFor(step, phase),
    });
    t += durationMs;
  };
  for (const part of exam.parts) {
    for (const step of part.steps) {
      push(part.index, step, "reader", step.audioMs + READER_GAP_MS);
      if (step.kind !== "narration") push(part.index, step, "speak", step.durationSec * 1000);
    }
  }
  return { segments, totalMs: t };
}

export type SessionPhase =
  | { state: "part1" | "part2" | "part3" | "part4"; segment: Segment; stepRemainingMs: number }
  | { state: "feedback"; remainingMs: number }
  | { state: "ended" };

/// What is happening `elapsedMs` after Part 1 started. Negative elapsed is
/// clamped to 0 (a client whose clock runs slightly behind the server).
export function phaseAt(timeline: Timeline, elapsedMs: number): SessionPhase {
  const e = Math.max(0, elapsedMs);
  if (e >= timeline.totalMs + FEEDBACK_MS) return { state: "ended" };
  if (e >= timeline.totalMs) return { state: "feedback", remainingMs: timeline.totalMs + FEEDBACK_MS - e };
  // Segments are sorted and contiguous: binary search.
  let lo = 0, hi = timeline.segments.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (timeline.segments[mid].startMs <= e) lo = mid; else hi = mid - 1;
  }
  const segment = timeline.segments[lo];
  // The visible timer counts down the whole step (reader + speaking window).
  let stepEnd = segment.endMs;
  const next = timeline.segments[lo + 1];
  if (next && next.stepId === segment.stepId) stepEnd = next.endMs;
  return {
    state: `part${segment.part}` as "part1",
    segment,
    stepRemainingMs: stepEnd - e,
  };
}
