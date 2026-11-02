# Observabilidad: Sentry y PostHog (preparado, pendiente de encender)

Decisión de Alfonso (2026-11-02): dejar Sentry (errores) y PostHog (producto/retención)
**preparados en código**, para encenderlos al final. Hoy todo es *no-op* mientras no haya claves,
así que no cambia el comportamiento ni rompe la compilación.

## Qué ya está en el código

### Backend (Edge Functions, Deno)
- `_shared/sentry.ts` — `captureException(err, context?)`. Sin dependencias: parsea el DSN y hace
  `POST` al Store API de Sentry con `fetch`. No-op si falta `SENTRY_DSN_FUNCTIONS`. Ya está
  enganchado en el `catch` del `handler` central (`_shared/http.ts`): cualquier error 500 lo
  reporta. No envía PII, solo tipo/mensaje/stack.
- `_shared/analytics.ts` — `track(event, distinctId, properties?)`. `POST` a `/capture` de PostHog.
  No-op si falta `POSTHOG_API_KEY`. `distinctId` debe ser el uuid del usuario; nunca propiedades con
  contenido personal.

### App (Flutter)
- `lib/core/telemetry/telemetry.dart` — `Telemetry.instance` con `init()`, `captureError()`,
  `track(AppEvent)` e `identify()`. No-op hasta que lleguen las claves por `--dart-define`
  (`SENTRY_DSN_APP`, `POSTHOG_API_KEY`, `POSTHOG_HOST`). El enum `AppEvent` lista los eventos
  mínimos de CLAUDE.md §11.

### Variables de entorno (ya reservadas en `.env.example`)
- Backend (secreto del proyecto Supabase): `SENTRY_DSN_FUNCTIONS`, `POSTHOG_API_KEY`,
  `POSTHOG_HOST` (opcional, por defecto `https://eu.i.posthog.com`), `SENTRY_ENVIRONMENT` (opcional).
- App (`--dart-define`): `SENTRY_DSN_APP`, `POSTHOG_API_KEY`, `POSTHOG_HOST`.

## Qué falta para encenderlo (el último paso)

1. **Crear las cuentas** de Sentry y PostHog y obtener el DSN y la API key. Elegir región **UE** en
   PostHog (`https://eu.i.posthog.com`) por el RGPD.
2. **Backend**: añadir los secretos al proyecto Supabase (`supabase secrets set ...` o el panel).
   A partir de ahí, Sentry ya recibe los 500 sin tocar nada. Para analítica, llamar a `track(...)`
   en los puntos de negocio del servidor: `svc_apply_rc_event` → `subscription_started/cancelled`,
   creación de sesión → `matchmaking_matched`, `svc_session_tick` al entrar en cada parte →
   `exam_part_started`, etc. (hacerlo en las Edge Functions, no en SQL).
3. **App**: añadir los paquetes `sentry_flutter` y `posthog_flutter` al `pubspec.yaml`, implementar
   los `TODO(observability)` de `telemetry.dart` (3 líneas cada uno), llamar a `Telemetry.instance.init()`
   en `main()` y a `identify(userId)` tras el login (y `identify(null)` al cerrar sesión). Sembrar los
   `track(AppEvent.x)` en las pantallas correspondientes.
4. **Legal**: añadir Sentry y PostHog como encargados del tratamiento en el apartado 5 de la Política
   de Privacidad y revisar la base jurídica (ver `docs/legal/ASPECTOS_A_COMPLETAR.md`, punto 9).
   PostHog: configurar sin IP ni identificador persistente, o pedir consentimiento.

## Principio

La analítica que importa (suscripción, emparejamientos, sesiones) se emite **desde el servidor**,
donde el cliente no puede falsearla. La app solo emite eventos de interacción pura (toques de
«ver texto», «ocultar reloj», anuncio mostrado) y los errores de la propia app.
