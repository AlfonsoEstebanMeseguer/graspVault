# Progreso

> Actualizado: 2026-10-29. Créditos hasta el 2026-11-04.

## Estado en el proyecto real (Supabase `SpeakingApp`, eu-central-1)

| Pieza | Estado |
|---|---|
| Migraciones aplicadas | `baseline_schema`, `rules_helpers_onboarding`, `rules_sessions`, `dev_access_and_internal_token`, `security_advisor_fixes` |
| Pendientes de 2026-10-15 | Ya aplicadas (el 2026-10-29 `list_migrations` muestra todo hasta `agenda_v2`) |
| Catálogo de exámenes | Cargado (3 exámenes; md5 verificado contra el repo) |
| Auditoría de permisos | `anon` sin ningún permiso; `authenticated` solo las columnas previstas |
| Asesor de seguridad | Solo el aviso informativo "RLS sin políticas" de las tablas de servidor (intencionado) |
| Edge Functions desplegadas | `onboarding-complete`, `matchmaking`, `session-actions`, `meeting-actions`, `media-view-url`, `avatar-upload-url`, `avatar-confirm`, `account-delete`, `livekit-webhook`, `cron-worker` + `config-check` (diagnóstico, se vaciará). Sin sesión, cada una devuelve su propio 401; `livekit-webhook` rechaza firmas falsas; `cron-worker` acepta el token de Vault |
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
| 8. Pulido | ⬜ | |

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
