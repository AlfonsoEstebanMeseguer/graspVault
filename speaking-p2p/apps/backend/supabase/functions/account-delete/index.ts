// Account deletion (required by both stores). An irreversible action is
// RE-AUTHENTICATED, a JWT alone is not enough (vault ADR 0016). With Google-only
// login the re-authentication is a fresh Google sign-in right before: the session
// must be younger than 5 minutes. Plus a confirmation phrase checked HERE.
import { z } from "npm:zod@3.23.8";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { adminClient, requireAuthUser, rpc } from "../_shared/supabase.ts";

const PHRASES = new Set(["ELIMINAR", "DELETE"]); // ES / EN, both accepted by the server
const Body = z.object({ confirmation: z.string() });

Deno.serve(handler(async (req) => {
  const { user, iat } = await requireAuthUser(req);
  const { confirmation } = await parseBody(req, Body);
  if (!PHRASES.has(confirmation.trim().toUpperCase())) throw new HttpError(422, "bad_confirmation");
  if (Date.now() / 1000 - iat > 300) throw new HttpError(401, "reauth_required");
  await rpc("svc_account_prepare_delete", { p_user: user.id });
  // delete from auth.users is the real GDPR path: cascades profiles, private data,
  // entitlements; set-null anonymises chat messages; triggers queue R2 objects.
  const { error } = await adminClient().auth.admin.deleteUser(user.id);
  if (error) throw new HttpError(500, "internal");
  return json({ deleted: true });
}));
