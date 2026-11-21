# Progreso

> Actualizado: 2026-10-31. Créditos hasta el 2026-11-04.

## Estado en el proyecto real (Supabase `SpeakingApp`, eu-central-1)

| Pieza | Estado |
|---|---|
| Migraciones aplicadas | `baseline_schema`, `rules_helpers_onboarding`, `rules_sessions`, `dev_access_and_internal_token`, `security_advisor_fixes` |
| Pendientes de 2026-10-15 | Ya aplicadas (el 2026-10-29 `list_migrations` muestra todo hasta `agenda_v2`) |
| Catálogo de exámenes | Cargado (3 exámenes; md5 verificado contra el repo) |
| Auditoría de seguridad 2026-11-20 | Aplicada en producción el 2026-11-21: migraciones `20261121092211`…`092250`, 10 Edge Functions redesplegadas, flags `dev_*` a `false`, Confirm email activado (`docs/SECURITY_AUDIT_2026-11.md`, D-070). `config-check` borrada (C-H2). Build 5 de iOS probado en TestFlight: subida de foto a R2, micro al reconectar y borrado de cuenta, todo correcto. Vigilancia de costes en §6 del informe. **Pendiente:** topes y alertas de gasto (Cloudflare, OpenAI), build de Android |
| Cuota de Edge Functions | 2026-11-21: los crons solo invocan `cron-worker` si hay trabajo (migración `20261121102751`, D-071). Antes ~13 000 invocaciones/día en reposo; después, 0 sin actividad. Verificado en logs y en `cron.job_run_details` |
| Auditoría de permisos | `anon` sin ningún permiso; `authenticated` solo las columnas previstas |
| Asesor de seguridad | Solo el aviso informativo "RLS sin políticas" de las tablas de servidor (intencionado) |
| Edge Functions desplegadas | `onboarding-complete`, `matchmaking`, `session-actions`, `meeting-actions`, `media-view-url`, `avatar-upload-url`, `avatar-confirm`, `account-delete`, `livekit-webhook`, `cron-worker` (`config-check` borrada el 2026-11-21). Sin sesión, cada una devuelve su propio 401; `livekit-webhook` rechaza firmas falsas; `cron-worker` acepta el token de Vault |
| Auth | Email + contraseña; confirmación de email desactivada (según Alfonso). Queda 1 usuario de prueba sin confirmar (`+e2e1`) creado antes de desactivarla: borrar en Authentication → Users |
| Aplazadas por decisión | Google Sign-In, RevenueCat, dominio CDN, TTS, Sentry, AdMob, PostHog, Firebase (push) |

## Estado por hito

| Hito | Estado | Notas |
|---|---|---|
| 0. Setup | ✅ | Scaffold, CI, lints, i18n ES/EN, tema claro/oscuro, VAULT_NOTES |
| 1. Auth y onboarding | ✅ con email (Google ⏸️) | Login/registro, onboarding de 3 pasos según bocetos, avatar en R2 (backend; falta el selector de fotos) |
| 2. Motor del examen offline | ✅ (sin audio) | Lector silencioso hasta tener TTS |
| 3. Llamada y sesión sincronizada | ✅ código / ⬜ probado con 2 móviles | LiveKit solo audio, lobby, reloj del servidor, micros por `canPublish` |
| 4. Matchmaking en vivo | ✅ código | Búsqueda con latido, aviso a los 15 s → Agenda › Crear reunión. Necesita las migraciones pendientes |
| 5. Agenda | ✅ código | Chats, tablón (filtro de nivel adyacente y día), mis ofertas con interesados, crear (máx. 2), elegir hora con "Ocupado", chat en tiempo real con tarjeta (Modificar/Cancelar/Confirmar, ✓/○, mensajes de sistema traducidos), Mi agenda con "Entrar a la sala" de −5 a +10 min, tarjeta de próxima reunión en Inicio. Push ⏸️ (Firebase) |
| 6. Acceso y monetización | 🟡 | Elegibilidad en servidor; "todos pagan" (D-020). **Plan Pro (10 €) con control del examen y líder (D-037…D-040)**: migraciones aplicadas en Supabase y `session-actions`, `livekit-webhook` y `cron-worker` desplegadas (`revenuecat-webhook` sigue sin desplegar: RevenueCat aplazado). Falta: prueba con dos móviles. Paywall/RevenueCat/App Open Ad ⏸️ |
| 7. Contenido completo, grabación, cuenta | 🟡 | Perfil (exámenes hechos, grabaciones con días restantes, editar), Ajustes (estado de suscripción, eliminar cuenta con contraseña + frase, D-027). Falta: reproductor de grabaciones, 4 exámenes más por nivel, Términos/Privacidad (textos) |
| 8. Pulido | 🟡 | 2026-10-31 (D-058): el cronómetro solo cuenta la respuesta, pitidos de inicio y fin con campana para silenciarlos, la Parte 2 muestra la pregunta antes que las fotos y el dock es fijo con pausa del examinador. **Pendiente:** aplicar `20261031120000_pause_during_reader.sql` en Supabase (hasta entonces, en vivo no se puede pausar durante la lectura) |

## Cómo se verifica hoy

```bash
# Contenido + funciones (Deno)
deno test --allow-read --allow-env scripts/content apps/backend/supabase/functions/_shared
deno check apps/backend/supabase/functions/*/index.ts
# SQL (Postgres ≥15 con el shim de Supabase)
PGHOST=... PGUSER=postgres apps/backend/supabase/tests/run-plain.sh
# ...o en Docker desde Git Bash (MSYS_NO_PATHCONV=1):
docker run -d --name pgtest -e POSTGRES_PASSWORD=pg -v "D:/VSCODE/SpeakingApp/graspVault/speaking-p2p:/repo" postgres:16
docker exec -u postgres pgtest bash -c "cd /repo/apps/backend/supabase && PGUSER=postgres bash tests/run-plain.sh"
# App
cd apps/mobile && flutter analyze && flutter test
```

2026-10-25 (tarde): migración `20261025085249_report_block` **aplicada** en Supabase (asesor sin avisos nuevos inesperados). App solo en vertical (iPad con `UIRequiresFullScreen`) y ondas del botón de Inicio en mandarina (D-043). `flutter analyze` limpio, 87 tests ✅; la prueba de capturas volvía a fallar porque no sustituía `safetyRepositoryProvider` (arreglado). Agenda v2 aprobada e implementada (D-046): migración `20261025160537_agenda_v2` aplicada en Supabase (SQL 01–10 ✅ en Docker) y `meeting-actions` v3 desplegada (códigos de error nuevos en `_shared/http.ts`). 98 tests Flutter ✅.

2026-10-25: **87 tests Flutter ✅**, SQL 01–09 ✅ (en Docker). Migración `report_block` pendiente de aplicar en Supabase.

2026-10-24: **79 tests Flutter ✅**, 12 Deno ✅, SQL 01–07 ✅ (en Docker, Postgres 16), `flutter analyze` y `deno check` limpios.

Resultado anterior (2026-10-15): 17 tests Deno ✅, 5 ficheros SQL ✅, **50 tests Flutter ✅** (también con `TZ=Europe/Madrid`), `flutter analyze` y `deno check` limpios. El script del SQL Editor se probó en Postgres local (aplica, registra la versión, se niega a repetir).

## Lo que NO está verificado contra el sistema real

- Las tres migraciones pendientes en Supabase (ver arriba) y, por tanto, el flujo E2E de agenda/matchmaking/borrado contra el servidor.
- La app en un dispositivo Android/iOS (aquí no hay SDK de Android) y una llamada real entre dos móviles.
- LiveKit (`UpdateParticipant`, Egress): fixtures escritos a partir de la documentación.

## Stubs y mocks activos

| Qué | Por qué | Cómo se quita |
|---|---|---|
| Lector silencioso | No hay TTS | Proveedor de TTS + subir audio a R2 |
| Push (`sendPush` "not configured") | Sin Firebase | Proyecto Firebase + `FCM_SERVICE_ACCOUNT_JSON` |
| Grabaciones sin botón de reproducir | Falta un paquete de audio | Añadir reproductor (p. ej. `just_audio`) usando `media-view-url {recording}` |
| Suscripción solo informativa | RevenueCat aplazado | SDK + webhook (ya escrito) |

## Rediseño 2.0 (2026-10-24, D-043)
- Hecho: tokens, tema, fuentes, iconos, tab bar glass, login/registro (Apple y Google solo interfaz), onboarding, Inicio, búsqueda, sala de espera, examen (progreso, reloj de anillo, tira A/B, tarjeta obsidiana, fotos en carrusel, diagrama manuscrito, dock del líder + hoja «Más»), feedback con rúbrica (D-042), agenda, chat, perfil y ajustes. Capturas en `docs/screenshots/`.
- Pendiente: probarlo en el Xiaomi; conectar Sign in with Apple / Google cuando se decida.

## Fotos de la Parte 2 (2026-10-28, D-047)
- 416 de 612 elegidas a mano en Pixabay (hojas de contacto por examen), comprimidas a WebP 4:3 (media 69 KB, ~28 MB en total) y subidas a R2. Autor y página de cada una en `content/LICENSES.md`.
- 196 generadas con la API de OpenAI (`gpt-image-1-mini`, calidad media, 2,49 $) con los prompts de `content/photos/PROMPTS_IA.md`, revisadas una a una (3 rehechas: un emblema de la Cruz Roja y 2 bloqueadas por el filtro). **612 de 612 en R2: los 153 exámenes tienen todas sus fotos.**

## Sesión 2026-10-29
- **Tarea 1 · Examinador mudo hasta tocar el volumen (D-048):** arreglado en código (una sola dueña de la sesión de audio). `flutter analyze` limpio. **Falta probarlo en el iPhone y en el Xiaomi:** compilar el `.ipa` cuando lo apruebe Alfonso.
- **Tarea 2 · Botón naranja en la Agenda (D-050):** hecho, en el estado vacío de «Mis exámenes». Test y capturas (`02-agenda-y-cuenta`).
- **Tarea 3 · Diagrama de la Parte 3 (D-049):** hecho, con test de solapes y capturas en claro y oscuro (`05-diagrama-parte-3`).
- **Tarea 4 · Preguntas de la Parte 2 (D-052):** hecho, formateando en la app. Test de los 153 exámenes (texto idéntico) y captura (`03-sesion-y-examen`).
- **Tarea 5 · Reportes por sabotaje:** análisis aprobado. **Fase 1 implementada (D-051):** registro de eventos, tiempo de voz por tramo, motivos nuevos y reportes ligados a la sesión. SQL 01–11 ✅ (Docker, Postgres 16), 22 Deno ✅. **Sin desplegar:** el permiso automático de Claude Code bloqueó el despliegue a producción. Falta aplicar la migración y desplegar `session-actions` y `livekit-webhook`. En remoto hay 0 reportes duplicados, así que el índice único se puede crear.
- **Tras probar el `.ipa` (2026-10-29):** el saludo inicial del examinador no sonaba. Causa encontrada y arreglada (D-053), con cuenta atrás grande de 3 s. «Proponer el mío» del tablón vacío pasa a ser el círculo naranja.
- Tests: **125 Flutter ✅**, `flutter analyze` limpio, `deno check` limpio, 22 Deno ✅ y SQL 01–11 ✅.

## Siguiente paso

1. **Alfonso:** pegar `apps/backend/supabase/manual/apply_pending_2026-10-15.sql` en Supabase › SQL Editor › Run, y borrar el usuario de prueba sin confirmar.
2. Yo: comprobar migraciones/advisors, prueba E2E por HTTP (crear oferta, aceptar, confirmar, entrar, borrar cuenta) y vaciar `config-check`.
3. Probar la app en dos móviles (llamada, lobby, examen sincronizado).

## Sesión 2026-11-02
- **Parte 3 · tiempo para pensar (D-059):** `prepSec` (15 s) en B2 y C1; silencio al final del segmento del lector, micros cerrados, «Saltar» lo salta. UI «Tiempo para pensar». Catálogo regenerado y **aplicado en Supabase** (102 exámenes). Fotos de la Parte 2 **en vertical** (apiladas) en vez del carrusel.
- **Términos y Privacidad finalizados (D-060):** documentos limpios de notas internas, correos de contacto puestos, versión `2026-11-02`. Lo pendiente de decidir (titular, edad, proveedores, DSA, ads, analítica) en `docs/legal/ASPECTOS_A_COMPLETAR.md`. La aceptación en el registro ya existía.
- **Auditoría de seguridad (`docs/SECURITY_AUDIT_2026-11-02.md`):** revisión estática + introspección de privilegios en producción + skill de seguridad. **Sin vulnerabilidades explotables.** Dos endurecimientos menores (protección de contraseñas filtradas; rate limiting).
- **Observabilidad preparada (D-061):** Sentry y PostHog andamiados *no-op* hasta tener claves (backend `_shared/sentry.ts` + `analytics.ts`, app `core/telemetry/telemetry.dart`). Guía en `docs/OBSERVABILITY.md`.
- **Decisiones de infraestructura:** `docs/EVAL_REDIS_REVENUECAT.md` — RevenueCat sí (ya andamiado, encender al monetizar); Redis todavía no (Postgres + LiveKit cubren el volumen actual).
- **Marketing:** `docs/MARKETING.md` — posicionamiento, viralidad P2P, arranque en frío, canales, embudo y lanzamiento.
- Tests: Flutter ✅ (incl. legal y onboarding), `flutter analyze` limpio, `deno check` limpio, golden/golden-SQL ✅. Nuevo `.ipa` compilado (run 41422181082).

## Sesión 2026-11-18 · Login con Google y Apple (D-062)
- **Hecho en código:**
  - `data/auth/oauth_sign_in.dart` (Google y Apple → `signInWithIdToken` con nonce);
  - botones de la bienvenida conectados (Apple solo en iOS);
  - borrado de cuenta que reautentica con el proveedor, con protección contra borrar otra cuenta;
  - `account-delete` revoca el token de Apple (`_shared/apple.ts`, con tests);
  - `Runner.entitlements` y el URL scheme de iOS generado desde `env/dev.json`.
- **Verificado:** `flutter analyze` sin avisos, `flutter test` 137/137 y `deno test _shared/apple_test.ts` 3/3. **Sin probar en un dispositivo real:** faltan los client IDs.
- **Bloqueado por credenciales:** cuentas de Google Cloud y Apple Developer (Alfonso las crea el 2026-11-18). Pasos exactos en `docs/AUTH_OAUTH_SETUP.md`.
- **Siguiente:**
  1. Poner los client IDs en `env/dev.json`, activar Google en Supabase y probar en Android e iOS.
  2. Redesplegar `account-delete`.
  3. Con la cuenta de Apple: secretos `APPLE_*`, `APPLE_SIGN_IN=true` y firma en CI para TestFlight.
- **2026-11-19 · Google funciona en Android (Redmi 12C):**
  - Clientes OAuth creados en el proyecto de Google Cloud «MirloTalk». Los IDs web e iOS están en `env/dev.json` y Google está activado en Supabase con los dos IDs.
  - Primer intento: `Unacceptable audience in id_token`, porque faltaba el ID web en Supabase. Corregido.
  - La cuenta de Google se unió a la cuenta de email existente con el mismo Gmail (`providers: [email, google]`). Por eso sigue reautenticándose con contraseña al borrar (`provider` = `email`).
- **2026-11-19 · `account-delete` v2 desplegada** (bundle con `scripts/deploy/bundle-functions.mjs` + MCP, `verify_jwt` igual que antes). Sin sesión → 401; OPTIONS → 200. La revocación de Apple queda en `skipped` hasta poner los secretos `APPLE_*`.
  - **Pendiente:** probar Google en el iPhone (build de iOS + Sideloadly) y todo lo de Apple (cuenta de pago).
## Sesión 2026-11-19
- **Sentry y PostHog implementados (D-063):** SDKs en la app (`sentry_flutter`, `posthog_flutter`), `identify` por uuid, eventos de interacción; en el servidor, `signup`/`subscription` directos y el resto por `analytics_outbox` (triggers) + `cron-worker` `analytics`. Todo sigue siendo no-op sin claves.
- Tests: Flutter ✅ (139, incl. `telemetry_test`), `flutter analyze` limpio, `deno check`/`lint`/`test` ✅ (16), suite SQL ✅ (12, incl. `12_analytics.sql`).
- **Desplegado en producción (2026-11-19):** migración `analytics_outbox` (MCP), `cron-worker` v5 y `onboarding-complete` v4. Cron `analytics` activo y respondiendo `{"sent":0}` (= `POSTHOG_API_KEY` presente). Secretos comprobados por nombre con `config-check`: `SENTRY_DSN_FUNCTIONS` y `POSTHOG_API_KEY` presentes.
- **Producción al día con el repo (2026-11-19, tarde):** aplicadas `moderation_evidence` y `pause_during_reader` (antes faltaban) y versiones de las 3 migraciones de hoy canonizadas a las del repo en `schema_migrations`. Redesplegadas todas las funciones salvo `revenuecat-webhook` (RevenueCat aplazado): `session-actions` v7, `livekit-webhook` v5, `matchmaking` v4, `meeting-actions` v6, `media-view-url` v5, `avatar-upload-url` v4, `avatar-confirm` v5, `account-delete` v5 (+ `cron-worker` v5, `onboarding-complete` v4). Las 10 arrancan (OPTIONS 200, 401 propio sin sesión); crons sin fallos.
- **App con telemetría probada en Redmi y emulador:** claves en `env/dev.json`; partida real completa → 15 eventos de servidor + los de la app en PostHog, sin fallos.
- **Legal y cuenta (D-065, D-066), aplicado en producción:** migraciones `drop_phone_bans`, `min_age_16` y `terms_reaccept` (versiones canonizadas); `onboarding-complete` v5 (sin teléfono, `banned` → 403) y `account-delete` v6 (borrado en PostHog, apagado hasta tener la clave personal). Sin teléfono, edad mínima 16, expulsión con hash del correo (`private.ban_user`), reportes en 72 h, pantalla de re-aceptación, titular en los documentos, licencias en Ajustes. Tests: SQL 14/14, Deno 18, Flutter 147, analyze limpio.
- **Lanzamiento gratis y sin marcas (D-067):** niveles MCER en lugar de nombres de Cambridge; suscripciones y práctica premium ocultas con `Features`; práctica con examen aleatorio; formularios de las tiendas en `docs/legal/FORMULARIOS_TIENDAS.md`. Flutter 147 ✅.
- **Apple + TestFlight (2026-11-20, D-062):** cuenta Apple Developer aprobada; App ID `com.speakingp2p.speakingP2p` (el primero se creó con el sufijo `.77VU9TX592` y queda sin uso), clave SIWA y secretos `APPLE_*` en Supabase, `APPLE_SIGN_IN=true`. Workflow `speaking-p2p-testflight.yml` con los 6 secretos de firma en GitHub: build 2 subido a TestFlight sin errores (aviso: desde abril de 2027 hará falta el SDK de iOS 27). Material de firma fuera del repo en `Documentos\MirloTalk-secretos\ios-dist`. **Siguiente:** instalar desde TestFlight en el iPhone 15 y probar Apple y Google.
