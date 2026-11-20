// Writes content/fixtures/timeline-golden.json: the cross-language contract
// between the TypeScript timeline (server) and the Dart one (app).
// deno run --allow-read --allow-write scripts/content/golden.ts
import { Exam } from "../../apps/backend/supabase/functions/_shared/exam/schema.ts";
import { buildTimeline, phaseAt } from "../../apps/backend/supabase/functions/_shared/exam/timeline.ts";

export async function computeGolden() {
  const input = Exam.parse(JSON.parse(await Deno.readTextFile(new URL("../../content/fixtures/timeline-input.json", import.meta.url))));
  const timeline = buildTimeline(input);
  const probes = [-500, 0, 2599, 2600, 4699, 4700, 30000, 50000, 120000, timeline.totalMs - 1, timeline.totalMs, timeline.totalMs + 299_999, timeline.totalMs + 300_000];
  return {
    timeline,
    probes: probes.map((elapsedMs) => {
      const p = phaseAt(timeline, elapsedMs);
      return {
        elapsedMs,
        state: p.state,
        segmentIndex: "segment" in p ? p.segment.index : null,
        remainingMs: "stepRemainingMs" in p ? p.stepRemainingMs : ("remainingMs" in p ? p.remainingMs : null),
      };
    }),
  };
}

if (import.meta.main) {
  const out = new URL("../../content/fixtures/timeline-golden.json", import.meta.url);
  await Deno.writeTextFile(out, JSON.stringify(await computeGolden(), null, 2) + "\n");
  console.log(`wrote ${out.pathname}`);
}
