// Loads and validates everything under content/. Shared by the CLI scripts.
import {
  ContentIndex,
  Diagram,
  Exam,
  semanticErrors,
} from "../../apps/backend/supabase/functions/_shared/exam/schema.ts";

export const CONTENT_DIR = new URL("../../content/", import.meta.url);

export type LoadedContent = {
  index: ContentIndex;
  exams: Exam[];
  diagrams: Map<string, Diagram>;
  photos: Record<string, string>;
  errors: string[];
};

async function readJson(url: URL): Promise<unknown> {
  return JSON.parse(await Deno.readTextFile(url));
}

export async function loadContent(dir: URL = CONTENT_DIR): Promise<LoadedContent> {
  const errors: string[] = [];
  const index = ContentIndex.parse(await readJson(new URL("index.json", dir)));
  const diagrams = new Map<string, Diagram>();
  for (const id of index.diagrams) {
    const parsed = Diagram.safeParse(await readJson(new URL(`diagrams/${id}.json`, dir)));
    if (!parsed.success) {
      errors.push(`diagrams/${id}.json: ${parsed.error.message}`);
      continue;
    }
    if (parsed.data.id !== id) errors.push(`diagrams/${id}.json: id mismatch`);
    diagrams.set(id, parsed.data);
  }
  const photos = (await readJson(new URL("photos.json", dir))) as Record<string, string>;
  const exams: Exam[] = [];
  for (const entry of index.exams) {
    const path = `exams/${entry.level}/${entry.id}.json`;
    const parsed = Exam.safeParse(await readJson(new URL(path, dir)));
    if (!parsed.success) {
      errors.push(`${path}: ${parsed.error.message}`);
      continue;
    }
    const exam = parsed.data;
    if (exam.id !== entry.id || exam.level !== entry.level || exam.version !== entry.version) {
      errors.push(`${path}: id/level/version differ from index.json`);
    }
    for (const e of semanticErrors(exam, diagrams)) errors.push(`${path}: ${e}`);
    for (const part of exam.parts) {
      for (const st of part.steps) {
        if (st.kind === "turn") for (const a of st.assets ?? []) if (!photos[a]) errors.push(`${path}: ${st.id}: asset ${a} has no entry in photos.json`);
      }
    }
    exams.push(exam);
  }
  // Files on disk that the index forgot are a silent bug: the app would never ship them.
  for (const level of ["B1", "B2", "C1"]) {
    for await (const f of Deno.readDir(new URL(`exams/${level}/`, dir))) {
      const id = f.name.replace(/\.json$/, "");
      if (!index.exams.some((e) => e.id === id)) errors.push(`exams/${level}/${f.name}: not in index.json`);
    }
  }
  return { index, exams, diagrams, photos, errors };
}
