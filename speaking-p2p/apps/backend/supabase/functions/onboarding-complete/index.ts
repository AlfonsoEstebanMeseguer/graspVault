// Steps 2-8 of the onboarding in one atomic call (CLAUDE.md §3).
import { z } from "npm:zod@3.23.8";
import { handler, json, parseBody } from "../_shared/http.ts";
import { requireAuthUser, rpc } from "../_shared/supabase.ts";

const Body = z.object({
  username: z.string().trim().toLowerCase().regex(/^[a-z0-9_.]{3,20}$/),
  languages: z.array(z.string().regex(/^[a-z]{2}$/)).min(1).max(10),
  targetLevel: z.enum(["B1", "B2", "C1"]),
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  phone: z.string().regex(/^\+[0-9]{7,15}$/).nullable(),
  termsVersion: z.string().min(1).max(20),
});

Deno.serve(handler(async (req) => {
  const { user } = await requireAuthUser(req);
  const b = await parseBody(req, Body);
  const result = await rpc("svc_onboarding_complete", {
    p_user: user.id,
    p_email: user.email ?? null,
    p_username: b.username,
    p_languages: [...new Set(b.languages)],
    p_level: b.targetLevel,
    p_birth_date: b.birthDate,
    p_phone: b.phone,
    p_terms_version: b.termsVersion,
  });
  return json(result);
}));
