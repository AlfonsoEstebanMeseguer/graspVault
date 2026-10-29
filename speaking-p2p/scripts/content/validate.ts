// CI gate: deno run --allow-read scripts/content/validate.ts
import { loadContent } from "./lib.ts";
import { buildTimeline } from "../../apps/backend/supabase/functions/_shared/exam/timeline.ts";

const { exams, errors } = await loadContent();
for (const exam of exams) {
  const t = buildTimeline(exam);
  console.log(`${exam.level} ${exam.id} v${exam.version}: ${t.segments.length} segments, ${(t.totalMs / 60000).toFixed(1)} min`);
}
if (errors.length) {
  console.error(`\n${errors.length} content error(s):`);
  for (const e of errors) console.error(`  - ${e}`);
  Deno.exit(1);
}
console.log("content OK");
