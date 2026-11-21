// Regression tests for the 2026-11 security audit (docs/SECURITY_AUDIT_2026-11.md).
import { assertEquals } from "jsr:@std/assert@1";
import { presign } from "./r2.ts";

Deno.test("C6: el PUT del avatar firma tipo y tamano (no solo host)", async () => {
  Deno.env.set("R2_ENDPOINT_SPEAKING_MEDIA", "https://example.invalid/speaking-media");
  Deno.env.set("R2_MEDIA_ACCESS_KEY", "dummy-access");
  Deno.env.set("R2_MEDIA_SECRET_KEY", "dummy-secret");
  const url = new URL(await presign("PUT", "media", "avatars/a/b.jpg", 300, "image/jpeg", 1234));
  assertEquals(url.searchParams.get("X-Amz-SignedHeaders"), "content-length;content-type;host");
  const get = new URL(await presign("GET", "media", "avatars/a/b.jpg", 300));
  assertEquals(get.searchParams.get("X-Amz-SignedHeaders"), "host");
});
