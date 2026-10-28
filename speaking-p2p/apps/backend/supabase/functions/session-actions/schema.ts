// Request bodies of session-actions (kept apart so tests can import them without serving).
import { z } from "npm:zod@3.23.8";

const Id = z.string().uuid();

// Pro exam control (D-039): one schema per op, so the database only ever sees valid args.
export const ControlBody = z.discriminatedUnion("op", [
  z.object({ op: z.enum(["pause", "resume", "skip_reader", "next_step", "prev_step", "next_part", "end_exam", "repeat_step", "transfer"]) }),
  z.object({ op: z.literal("go_to_part"), args: z.object({ part: z.number().int().min(1).max(4) }) }),
  z.object({ op: z.literal("extend"), args: z.object({ deltaMs: z.union([z.literal(-30000), z.literal(30000), z.literal(60000), z.literal(120000)]) }) }),
  z.object({ op: z.literal("set_part_speak"), args: z.object({ ms: z.number().int().min(10_000).max(900_000) }) }),
  z.object({
    op: z.literal("switch_exam"),
    args: z.object({ examId: z.string().regex(/^[a-z0-9-]{3,80}$/).optional(), level: z.enum(["B1", "B2", "C1"]).optional() }).default({}),
  }),
]);

export const Body = z.discriminatedUnion("action", [
  z.object({ action: z.literal("join"), sessionId: Id, contentVersion: z.number().int().min(0).optional() }),
  z.object({ action: z.literal("flag"), sessionId: Id, flag: z.enum(["ready", "preloaded", "recording"]), value: z.boolean() }),
  z.object({ action: z.literal("tick"), sessionId: Id }),
  z.object({ action: z.literal("abort"), sessionId: Id, reason: z.enum(["left", "content_missing"]).default("left") }),
  // Debug only: the database refuses it unless app_config.dev_session_skip is on (D-031).
  z.object({ action: z.literal("skip"), sessionId: Id }),
  z.object({ action: z.literal("control"), sessionId: Id, expectedVersion: z.number().int().min(0), control: ControlBody }),
]);
