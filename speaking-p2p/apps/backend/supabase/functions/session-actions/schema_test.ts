import { assert, assertEquals } from "jsr:@std/assert@1";
import { Body } from "./schema.ts";

const sessionId = "00000000-0000-4000-8000-000000000000";

Deno.test("control: solo los deltas permitidos y ops conocidas (D-039)", () => {
  const ok = Body.safeParse({ action: "control", sessionId, expectedVersion: 3, control: { op: "extend", args: { deltaMs: 60000 } } });
  assert(ok.success);
  assert(!Body.safeParse({ action: "control", sessionId, expectedVersion: 3, control: { op: "extend", args: { deltaMs: 45000 } } }).success);
  assert(!Body.safeParse({ action: "control", sessionId, expectedVersion: 3, control: { op: "drop_table" } }).success);
  assert(!Body.safeParse({ action: "control", sessionId, expectedVersion: 3, control: { op: "go_to_part", args: { part: 5 } } }).success);
  assert(!Body.safeParse({ action: "control", sessionId, expectedVersion: 3, control: { op: "switch_exam", args: { examId: "x'; --" } } }).success);
});

Deno.test("control: cambio de examen aleatorio sin args; join con version de contenido", () => {
  const r = Body.safeParse({ action: "control", sessionId, expectedVersion: 0, control: { op: "switch_exam" } });
  assert(r.success);
  assertEquals(r.data.action === "control" && "args" in r.data.control ? r.data.control.args : null, {});
  assert(Body.safeParse({ action: "join", sessionId, contentVersion: 1 }).success);
  assert(Body.safeParse({ action: "join", sessionId }).success, "apps viejas sin version");
});

const win = {
  seg: 3, startedAtMs: 1_761_700_000_000, state: "part1", phase: "speak", paused: false, micA: true, micB: false,
  windowMs: 30000, speechAMs: 21000, speechBMs: 0, overlapMs: 0,
};

Deno.test("talk_stats: ventanas acotadas y coherentes (D-051)", () => {
  assert(Body.safeParse({ action: "talk_stats", sessionId, windows: [win] }).success);
  assert(Body.safeParse({ action: "talk_stats", sessionId, windows: [{ ...win, seg: -1, state: "lobby", phase: null }] }).success);
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: [] }).success, "al menos una");
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: Array(21).fill(win) }).success, "20 como mucho");
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: [{ ...win, speechAMs: 31000 }] }).success, "más voz que tiempo");
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: [{ ...win, speechBMs: 1000, overlapMs: 2000 }] }).success, "solape imposible");
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: [{ ...win, windowMs: 500 }] }).success, "ventanas de al menos 1 s");
  assert(!Body.safeParse({ action: "talk_stats", sessionId, windows: [{ ...win, state: "ended" }] }).success);
});

Deno.test("self_mute: solo un booleano", () => {
  assert(Body.safeParse({ action: "self_mute", sessionId, muted: true }).success);
  assert(!Body.safeParse({ action: "self_mute", sessionId, muted: "yes" }).success);
});
