// Account deletion (required by both stores). An irreversible action is
// RE-AUTHENTICATED, a JWT alone is not enough (vault ADR 0016): the app signs
// in again right before (password, Google or Apple, D-062), so the session must
// be younger than 5 minutes. Plus a confirmation phrase checked HERE.
// Apple accounts also send the fresh `appleAuthorizationCode`: we revoke the
// Apple token (guideline 5.1.1(v)). A revocation failure is reported but never
// blocks the deletion: the user's right to erasure comes first.
import { z } from "npm:zod@3.23.8";
import { revokeAppleAuthorization } from "../_shared/apple.ts";
import { inBackground } from "../_shared/background.ts";
import { handler, HttpError, json, parseBody } from "../_shared/http.ts";
import { captureException } from "../_shared/sentry.ts";
import { adminClient, requireAuthUser, rpc } from "../_shared/supabase.ts";

const PHRASES = new Set(["ELIMINAR", "DELETE"]); // ES / EN, both accepted by the server
const Body = z.object({ confirmation: z.string(), appleAuthorizationCode: z.string().min(1).max(2048).optional() });

Deno.serve(handler(async (req) => {
  const { user, iat } = await requireAuthUser(req);
  const { confirmation, appleAuthorizationCode } = await parseBody(req, Body);
  if (!PHRASES.has(confirmation.trim().toUpperCase())) throw new HttpError(422, "bad_confirmation");
  if (Date.now() / 1000 - iat > 300) throw new HttpError(401, "reauth_required");
  const usesApple = (user.app_metadata?.providers as string[] | undefined)?.includes("apple") ?? user.app_metadata?.provider === "apple";
  if (usesApple && appleAuthorizationCode) {
    try {
      const r = await revokeAppleAuthorization(appleAuthorizationCode);
      if (r === "skipped") console.warn("apple revocation skipped: APPLE_* secrets not set");
    } catch (e) {
      console.error("apple revocation failed", e);
      inBackground(captureException(e, { fn: "account-delete", step: "apple_revoke" }));
    }
  }
  await rpc("svc_account_prepare_delete", { p_user: user.id });
  // delete from auth.users is the real GDPR path: cascades profiles, private data,
  // entitlements; set-null anonymises chat messages; triggers queue R2 objects.
  const { error } = await adminClient().auth.admin.deleteUser(user.id);
  if (error) throw new HttpError(500, "internal");
  return json({ deleted: true });
}));
