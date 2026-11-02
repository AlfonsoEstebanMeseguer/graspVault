# Evaluación: ¿Redis? ¿RevenueCat? (2026-11-02)

Alfonso pidió considerar el uso de Redis y de RevenueCat para MirloTalk. Resumen por delante:

- **RevenueCat: sí.** Ya está elegido y medio montado; es la opción correcta para esta app. Solo
  falta encenderlo.
- **Redis: todavía no.** No resuelve ningún problema que hoy no esté ya resuelto con Postgres y
  LiveKit. Añadiría una pieza de infraestructura, un coste y un punto de fallo sin beneficio real al
  volumen actual. Merece la pena solo si aparecen cuellos de botella concretos que abajo se listan.

---

## RevenueCat

### Por qué encaja
- La app vende una suscripción mensual en **App Store y Google Play** (8 € Estándar, 10 € Pro).
  Gestionar los recibos de las dos tiendas, las renovaciones, los periodos de gracia, los reembolsos
  y las pruebas a mano es trabajoso y propenso a errores. RevenueCat normaliza las dos tiendas en un
  único estado de «entitlement» y te manda webhooks.
- El modelo de datos ya lo anticipa: la tabla `entitlements` (status, current_period_end, plan) se
  actualiza desde `revenuecat-webhook`. El mapeo de eventos está escrito y con tests
  (`_shared/revenuecat.ts`: `mapRcEvent`, `planOf`), el webhook verifica el secreto en tiempo
  constante, y hay un interruptor `assume_paid` para dar acceso mientras RevenueCat está apagado.
- Alternativa (StoreKit 2 + Play Billing a mano): más control, pero reimplementar lo que RevenueCat
  ya hace fiable no vale la pena para un equipo de una persona.

### Qué falta para encenderlo
1. Crear el proyecto en RevenueCat, dar de alta los productos y los «entitlements» `standard` y `pro`
   (el código ya asume esos dos identificadores; `pro` incluye lo de `standard`, D-037).
2. Poner `REVENUECAT_WEBHOOK_AUTH_SHA256` en los secretos de Supabase y la URL del webhook en el panel
   de RevenueCat.
3. App: `REVENUECAT_API_KEY_APPLE` / `_GOOGLE` por `--dart-define` e integrar el SDK
   (`purchases_flutter`) en el paywall y en Ajustes.
4. Quitar/!desactivar el `assume_paid` cuando el pago real funcione.
5. Añadir RevenueCat a la Política de Privacidad (apartado 5) — ver `docs/legal/ASPECTOS_A_COMPLETAR.md`.

---

## Redis

### Para qué se suele meter Redis, y qué pasa en MirloTalk hoy

| Uso típico de Redis | Situación actual en MirloTalk | ¿Hace falta Redis? |
|---|---|---|
| Cola de emparejamiento atómica | `svc_match_enqueue` ya empareja de forma atómica y FIFO en Postgres (`match_queue` con bloqueos de fila) | No |
| Presencia / «quién está en línea» | `live_activity()` cuenta sobre Postgres; la presencia de la sesión la lleva LiveKit + `session_events` | No al volumen actual |
| Estado efímero de la sesión | El servidor es la autoridad y deriva todo de `exam_started_at` (sin cronómetros); el estado vive en `exam_sessions` | No |
| Caché de lecturas calientes | El contenido de examen es estático y ya va en el bundle / con URLs firmadas; el catálogo se lee poco | No |
| Rate limiting | No hay; hoy se confía en los límites de plataforma de Supabase | Serviría, pero hay alternativas más simples |
| Colas de trabajo / jobs | `pg_cron` + `notification_outbox` + `storage_gc_queue` ya hacen de cola | No |
| Pub/Sub en tiempo real | Lo cubre **LiveKit** (data messages) y Supabase Realtime | No |

### Veredicto
Meter Redis ahora sería optimización prematura: un servicio más que desplegar, vigilar, pagar y que
puede caerse, para resolver problemas que Postgres y LiveKit ya resuelven a esta escala. Además rompe
una propiedad valiosa del diseño actual: **una sola fuente de verdad transaccional** (Postgres), sin
estado disperso que reconciliar.

### Cuándo reconsiderarlo (señales concretas)
- El emparejamiento se vuelve un cuello de botella con muchos usuarios simultáneos y la contención de
  filas en `match_queue` se nota (medir antes). Incluso entonces, `SELECT ... FOR UPDATE SKIP LOCKED`
  en Postgres aguanta mucho.
- Necesitas **rate limiting** distribuido de verdad. Primera opción más simple: el rate limiting del
  gateway de Supabase o un contador en Postgres con ventana; Redis (p. ej. Upstash, serverless) solo
  si eso no basta.
- Presencia a gran escala con muchísimas actualizaciones por segundo, donde escribir en Postgres sea
  caro. Hoy no es el caso.

### Si algún día entra
Usar un Redis **serverless** (Upstash) accesible por HTTP desde las Edge Functions (Deno), para no
montar y mantener un servidor. Introducirlo para **un** uso concreto y medido, no como capa general.

---

## Recomendación final
Encender **RevenueCat** cuando toque monetizar (hito 6). **No** añadir Redis ahora; dejar esta nota
como referencia y revisarla solo si aparece uno de los cuellos de botella de arriba, con métricas que
lo respalden.
