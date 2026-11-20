// Authoring helper: fills the derived fields of every exam step in place.
//   audio   -> deterministic R2 key audio/{level}/{examId}/{stepId}.mp3
//   audioMs -> estimate from word count, only while it is 0 (tts.ts writes the real value)
// deno run --allow-read --allow-write scripts/content/fill-derived.ts
import { CONTENT_DIR } from "./lib.ts";
import { audioPath, estimateAudioMs, ContentIndex } from "../../apps/backend/supabase/functions/_shared/exam/schema.ts";

const index = ContentIndex.parse(JSON.parse(await Deno.readTextFile(new URL("index.json", CONTENT_DIR))));
for (const entry of index.exams) {
  const url = new URL(`exams/${entry.level}/${entry.id}.json`, CONTENT_DIR);
  // deno-lint-ignore no-explicit-any
  const exam: any = JSON.parse(await Deno.readTextFile(url));
  for (const part of exam.parts) {
    for (const step of part.steps) {
      step.audio = audioPath(exam.level, exam.id, step.id);
      if (!step.audioMs) step.audioMs = estimateAudioMs(step.text);
    }
  }
  await Deno.writeTextFile(url, JSON.stringify(exam, null, 2) + "\n");
  console.log(`filled ${url.pathname}`);
}
