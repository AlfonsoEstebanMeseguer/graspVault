// Exam content schema. Single source of truth for the shape of
// content/exams/{level}/{examId}.json and content/diagrams/{id}.json.
// Used by: scripts/content (validation in CI, catalog sync) and the
// session Edge Functions (server-side timeline).
import { z } from "npm:zod@3.23.8";

export const LEVELS = ["B1", "B2", "C1"] as const;
export type Level = typeof LEVELS[number];

const slug = z.string().regex(/^[a-z0-9][a-z0-9-]{1,62}$/);

// audioMs is the measured length of the reader audio. It is filled in by
// scripts/content/tts.ts once the audio exists; before that the validator
// accepts an estimate (see estimateAudioMs). Without it the server cannot
// know when the reader stops talking, so it is mandatory (DECISIONS D-004).
const base = {
  id: slug,
  text: z.string().trim().min(1).max(600),
  audio: z.string().min(1),
  audioMs: z.number().int().min(0).max(120_000),
};

export const NarrationStep = z.object({
  ...base,
  kind: z.literal("narration"),
}).strict();

export const TurnStep = z.object({
  ...base,
  kind: z.literal("turn"),
  target: z.enum(["A", "B"]),
  durationSec: z.number().int().min(5).max(180),
  assets: z.array(slug).max(3).optional(),
}).strict();

export const OpenStep = z.object({
  ...base,
  kind: z.literal("open"),
  target: z.enum(["A", "B", "both"]),
  durationSec: z.number().int().min(5).max(360),
  diagram: slug.optional(),
}).strict();

export const Step = z.discriminatedUnion("kind", [NarrationStep, TurnStep, OpenStep]);
export type Step = z.infer<typeof Step>;

export const Part = z.object({
  index: z.union([z.literal(1), z.literal(2), z.literal(3), z.literal(4)]),
  title: z.string().min(1),
  steps: z.array(Step).min(1),
}).strict();
export type Part = z.infer<typeof Part>;

export const Exam = z.object({
  id: slug,
  level: z.enum(LEVELS),
  version: z.number().int().min(1),
  topic: z.string().min(1),
  parts: z.array(Part).length(4),
}).strict();
export type Exam = z.infer<typeof Exam>;

export const Diagram = z.object({
  id: slug,
  centralQuestion: z.string().min(1).max(200),
  prompts: z.array(z.string().min(1).max(60)).length(5),
  decisionQuestion: z.string().min(1).max(200),
}).strict();
export type Diagram = z.infer<typeof Diagram>;

export const ContentIndex = z.object({
  version: z.number().int().min(1),
  exams: z.array(z.object({
    id: slug,
    level: z.enum(LEVELS),
    version: z.number().int().min(1),
    topic: z.string(),
  }).strict()),
  diagrams: z.array(slug),
}).strict();
export type ContentIndex = z.infer<typeof ContentIndex>;

/// Number of photos each candidate gets in Part 2, per level (CLAUDE.md §4).
export const PART2_ASSETS_PER_TURN: Record<Level, number> = { B1: 1, B2: 2, C1: 3 };

export const audioPath = (level: Level, examId: string, stepId: string) =>
  `audio/${level}/${examId}/${stepId}.mp3`;
export const imagePath = (level: Level, examId: string, assetId: string) =>
  `img/${level}/${examId}/${assetId}.webp`;

/// ~150 words per minute, neutral examiner voice. Only used before TTS exists.
export function estimateAudioMs(text: string): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1000, Math.round((words / 150) * 60_000));
}

/// Semantic rules Zod cannot express. Returns a list of human-readable errors
/// (empty = valid). Keep messages stable: CI prints them.
export function semanticErrors(exam: Exam, diagrams: Map<string, Diagram>): string[] {
  const errors: string[] = [];
  const seen = new Set<string>();
  exam.parts.forEach((part, i) => {
    if (part.index !== i + 1) errors.push(`part ${i}: index must be ${i + 1}`);
    for (const step of part.steps) {
      if (seen.has(step.id)) errors.push(`${step.id}: duplicate step id`);
      seen.add(step.id);
      const expected = audioPath(exam.level, exam.id, step.id);
      if (step.audio !== expected) errors.push(`${step.id}: audio must be ${expected}`);
      const interactive = part.index <= 2 ? "turn" : "open";
      if (step.kind !== "narration" && step.kind !== interactive) {
        errors.push(`${step.id}: part ${part.index} only allows narration and ${interactive} steps`);
      }
      if (step.kind === "turn" && part.index === 2) {
        const n = step.assets?.length ?? 0;
        // The short follow-up answer of the other candidate has no photos.
        if (n !== 0 && n !== PART2_ASSETS_PER_TURN[exam.level]) {
          errors.push(`${step.id}: ${exam.level} part 2 turns need ${PART2_ASSETS_PER_TURN[exam.level]} photos (or none for the follow-up)`);
        }
      }
      if (step.kind === "open" && step.diagram && !diagrams.has(step.diagram)) {
        errors.push(`${step.id}: unknown diagram ${step.diagram}`);
      }
    }
    if (!part.steps.some((s) => s.kind !== "narration")) {
      errors.push(`part ${part.index}: needs at least one speaking step`);
    }
  });
  const p3 = exam.parts[2];
  if (p3 && !p3.steps.some((s) => s.kind === "open" && s.diagram)) {
    errors.push("part 3: needs an open step with a diagram");
  }
  const firstTurn = (idx: number) =>
    exam.parts[idx]?.steps.find((s) => s.kind === "turn") as { target: string } | undefined;
  for (const idx of [0, 1]) {
    const t = firstTurn(idx);
    if (t && t.target !== "A") errors.push(`part ${idx + 1}: candidate A opens the part`);
  }
  return errors;
}
