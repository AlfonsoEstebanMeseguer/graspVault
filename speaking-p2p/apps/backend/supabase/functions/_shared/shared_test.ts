import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { fromDbError, handler, HttpError } from "./http.ts";
import { requireSecretHash, sha256Hex } from "./internal.ts";
import { permissionBody, signJwt, verifyWebhook } from "./livekit.ts";
import { mapRcEvent, rcAnalyticsEvent } from "./revenuecat.ts";
import { captureBatch, toBatchBody } from "./analytics.ts";
import { sniffImage } from "./r2.ts";
import { deletePosthogPerson, personDeleteRequest } from "./posthog_admin.ts";

Deno.test("el preflight CORS se corta antes de mirar la sesion (punto 15 del vault)", async () => {
  let called = false;
  const h = handler(async () => { called = true; throw new HttpError(401, "unauthenticated"); });
  const res = await h(new Request("http://x", { method: "OPTIONS" }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
  assert(!called, "el handler no debe ejecutarse en OPTIONS");
});

Deno.test("solo POST", async () => {
  const res = await handler(async () => new Response("x"))(new Request("http://x", { method: "GET" }));
  assertEquals(res.status, 405);
});

Deno.test("los codigos de negocio se mapean y lo desconocido es 500 sin filtrar detalles", async () => {
  assertEquals(fromDbError({ message: "not_eligible", code: "P0001" })?.status, 402);
  assertEquals(fromDbError({ message: "overlap", code: "P0001" })?.code, "overlap");
  const unknown = fromDbError({ message: "relation x does not exist", code: "42P01" });
  assertEquals([unknown?.status, unknown?.code], [500, "internal"]);
  const res = await handler(async () => { throw new Error("secreto interno"); })(new Request("http://x", { method: "POST" }));
  assertEquals(await res.json(), { error: "internal" });
});

Deno.test("token interno: compara el hash y falla cerrado", async () => {
  const hash = await sha256Hex("s3cret");
  await requireSecretHash("s3cret", hash);
  await assertRejects(() => requireSecretHash("otro", hash), HttpError, "unauthenticated");
  await assertRejects(() => requireSecretHash(null, hash), HttpError, "unauthenticated");
  await assertRejects(() => requireSecretHash("s3cret", undefined), HttpError, "not_configured");
  await assertRejects(() => requireSecretHash("s3cret", "s3cret"), HttpError, "not_configured"); // el valor en claro no vale como hash
});

Deno.test("UpdateParticipant manda SIEMPRE el permiso completo en snake_case", () => {
  const body = permissionBody("exam_x", "u1", false);
  assertEquals(body.permission.can_subscribe, true, "quitar publish no puede quitar subscribe");
  assertEquals(body.permission.can_publish, false);
  assertEquals(body.permission.can_publish_data, true);
});

Deno.test("webhook de LiveKit: acepta la firma correcta y rechaza cuerpo alterado o firma ajena", async () => {
  const body = JSON.stringify({ event: "participant_left", room: { name: "exam_x" } });
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body)));
  const jwt = await signJwt({ sha256: btoa(String.fromCharCode(...digest)) }, "key", "secret");
  assert(await verifyWebhook(body, jwt, "secret"));
  assert(!(await verifyWebhook(body + " ", jwt, "secret")), "cuerpo alterado");
  assert(!(await verifyWebhook(body, jwt, "otro-secreto")), "firma ajena");
  assert(!(await verifyWebhook(body, null, "secret")), "sin cabecera");
});

Deno.test("RevenueCat: cancelar no quita el periodo pagado; expirar si", () => {
  const base = { id: "e", app_user_id: "u", event_timestamp_ms: 1, expiration_at_ms: 2_000_000_000_000 };
  assertEquals(mapRcEvent({ ...base, type: "INITIAL_PURCHASE" })?.status, "active");
  assertEquals(mapRcEvent({ ...base, type: "CANCELLATION" })?.status, "cancelled");
  assertEquals(mapRcEvent({ ...base, type: "EXPIRATION" })?.status, "expired");
  assertEquals(mapRcEvent({ ...base, type: "TEST" }), null);
});

Deno.test("RevenueCat: el plan sale de los entitlements (D-037)", () => {
  const base = { id: "e", app_user_id: "u", event_timestamp_ms: 1, expiration_at_ms: 2_000_000_000_000, type: "PRODUCT_CHANGE" };
  assertEquals(mapRcEvent({ ...base, entitlement_ids: ["standard", "pro"] })?.plan, "pro");
  assertEquals(mapRcEvent({ ...base, entitlement_ids: ["standard"] })?.plan, "standard");
  assertEquals(mapRcEvent({ ...base, entitlement_ids: null })?.plan, null, "sin ids no se toca el plan");
});

Deno.test("magic bytes: webp y jpeg si; png o basura no", () => {
  const webp = new TextEncoder().encode("RIFF\0\0\0\0WEBPVP8 ");
  assertEquals(sniffImage(webp), "webp");
  assertEquals(sniffImage(new Uint8Array([0xff, 0xd8, 0xff, 0xe0])), "jpg");
  assertEquals(sniffImage(new Uint8Array([0x89, 0x50, 0x4e, 0x47])), null);
  assertEquals(sniffImage(new Uint8Array([])), null);
});

Deno.test("R2: el bucket sale del endpoint y los valores se recortan", async () => {
  const { parseEndpoint, kindForKey } = await import("./r2.ts");
  assertEquals(parseEndpoint(" https://abc.r2.cloudflarestorage.com/speaking-media/\n"),
    { origin: "https://abc.r2.cloudflarestorage.com", bucket: "speaking-media" });
  let threw = false;
  try { parseEndpoint("https://abc.r2.cloudflarestorage.com"); } catch { threw = true; }
  assert(threw, "sin bucket en la ruta es un error, no un 403 misterioso despues");
  assertEquals(kindForKey("recordings/x.ogg"), "recordings");
  assertEquals(kindForKey("audio/B2/e/s.mp3"), "content");
  assertEquals(kindForKey("avatars/u/x.webp"), "media");
});

Deno.test("analitica: el lote lleva el uuid, la hora del hecho y nunca geolocaliza el servidor", () => {
  const body = toBatchBody("phc_x", [
    { event: "exam_part_started", distinctId: "u1", properties: { part: 2 }, timestamp: "2026-11-19T10:00:00.000Z" },
    { event: "signup_completed", distinctId: "u2" },
  ], new Date("2026-11-19T11:00:00.000Z"));
  assertEquals(body.api_key, "phc_x");
  assertEquals(body.batch[0], {
    event: "exam_part_started", distinct_id: "u1", timestamp: "2026-11-19T10:00:00.000Z",
    properties: { part: 2, $lib: "mirlotalk-edge", $geoip_disable: true },
  });
  assertEquals(body.batch[1].timestamp, "2026-11-19T11:00:00.000Z");
});

Deno.test("analitica: sin POSTHOG_API_KEY no se envia nada", async () => {
  Deno.env.delete("POSTHOG_API_KEY");
  assertEquals(await captureBatch([{ event: "signup_completed", distinctId: "u" }]), false);
});

Deno.test("RevenueCat -> PostHog: solo la primera compra y la cancelacion", () => {
  assertEquals(rcAnalyticsEvent("INITIAL_PURCHASE"), "subscription_started");
  assertEquals(rcAnalyticsEvent("CANCELLATION"), "subscription_cancelled");
  assertEquals(rcAnalyticsEvent("RENEWAL"), null);
  assertEquals(rcAnalyticsEvent("TEST"), null);
});

Deno.test("PostHog: el borrado de cuenta pide borrar persona y eventos por el uuid, en la API privada de la UE", () => {
  const r = personDeleteRequest("phx_k", "123", "uuid-1");
  assertEquals(r.url, "https://eu.posthog.com/api/projects/123/persons/bulk_delete/");
  assertEquals(r.init.method, "POST");
  assertEquals((r.init.headers as Record<string, string>).Authorization, "Bearer phx_k");
  assertEquals(JSON.parse(r.init.body as string), { distinct_ids: ["uuid-1"], delete_events: true });
});

Deno.test("PostHog: sin clave personal no se llama a nadie", async () => {
  Deno.env.delete("POSTHOG_PERSONAL_API_KEY");
  assertEquals(await deletePosthogPerson("uuid-1"), "skipped");
});
