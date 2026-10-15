import { assert, assertEquals } from "jsr:@std/assert@1";
import { loadContent } from "./lib.ts";
import { computeGolden } from "./golden.ts";
import { Exam, semanticErrors } from "../../apps/backend/supabase/functions/_shared/exam/schema.ts";
import { buildTimeline, phaseAt, FEEDBACK_MS } from "../../apps/backend/supabase/functions/_shared/exam/timeline.ts";

Deno.test("el contenido versionado es valido", async () => {
  const { errors, exams } = await loadContent();
  assertEquals(errors, []);
  for (const level of ["B1", "B2", "C1"]) assert(exams.some((e) => e.level === level), `falta ${level}`);
});

Deno.test("el golden de la linea temporal no ha cambiado sin regenerarse", async () => {
  const onDisk = JSON.parse(await Deno.readTextFile(new URL("../../content/fixtures/timeline-golden.json", import.meta.url)));
  assertEquals(await computeGolden(), onDisk);
});

Deno.test("micros: lector silencia a los dos; turn solo al destinatario; open a los dos", async () => {
  const { timeline } = await computeGolden();
  for (const s of timeline.segments) {
    if (s.phase === "reader") assertEquals(s.mic, { A: false, B: false });
    else if (s.kind === "turn") assertEquals(s.mic, { A: s.target === "A", B: s.target === "B" });
    else assertEquals(s.mic, { A: true, B: true });
  }
});

Deno.test("los segmentos son contiguos y el feedback dura 5 min", async () => {
  const { timeline } = await computeGolden();
  for (let i = 1; i < timeline.segments.length; i++) {
    assertEquals(timeline.segments[i].startMs, timeline.segments[i - 1].endMs);
  }
  assertEquals(phaseAt(timeline, timeline.totalMs).state, "feedback");
  assertEquals(phaseAt(timeline, timeline.totalMs + FEEDBACK_MS).state, "ended");
});

Deno.test("las duraciones de cada nivel se parecen al examen real", async () => {
  const { exams } = await loadContent();
  const range: Record<string, [number, number]> = { B1: [10, 17], B2: [12, 16], C1: [13, 17] };
  for (const exam of exams) {
    const min = buildTimeline(exam).totalMs / 60000;
    const [lo, hi] = range[exam.level];
    assert(min >= lo && min <= hi, `${exam.id}: ${min.toFixed(1)} min fuera de [${lo}, ${hi}]`);
  }
});

Deno.test("las reglas semanticas muerden", async () => {
  const { exams, diagrams } = await loadContent();
  const exam: Exam = structuredClone(exams.find((e) => e.level === "B2")!);
  // Part 1 abierta por B en vez de A
  const firstTurn = exam.parts[0].steps.find((s) => s.kind === "turn")!;
  (firstTurn as { target: string }).target = "B";
  // Un open en la parte 1
  exam.parts[0].steps.push({ id: "bad-open", kind: "open", target: "both", text: "x", audio: "audio/B2/b2-community-life/bad-open.mp3", audioMs: 1000, durationSec: 10 });
  // Ruta de audio no determinista
  exam.parts[1].steps[0].audio = "audio/wrong.mp3";
  const errs = semanticErrors(exam, diagrams).join("\n");
  assert(errs.includes("candidate A opens the part"), errs);
  assert(errs.includes("only allows narration and turn"), errs);
  assert(errs.includes("audio must be"), errs);
});

Deno.test("seed/exam_catalog.sql esta al dia con content/", async () => {
  const { catalogSql } = await import("./sync-catalog.ts");
  const onDisk = await Deno.readTextFile(new URL("../../apps/backend/supabase/seed/exam_catalog.sql", import.meta.url));
  assertEquals(onDisk, await catalogSql(), "ejecuta scripts/content/sync-catalog.ts");
});

Deno.test("la copia del contenido en la app esta al dia", async () => {
  const { appFiles, APP_CONTENT_DIR } = await import("./sync-app.ts");
  for (const [rel, text] of await appFiles()) {
    const onDisk = await Deno.readTextFile(new URL(rel, APP_CONTENT_DIR)).catch(() => null);
    assertEquals(onDisk, text, `${rel} desactualizado: ejecuta scripts/content/sync-app.ts`);
  }
});
