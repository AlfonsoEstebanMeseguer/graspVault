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
