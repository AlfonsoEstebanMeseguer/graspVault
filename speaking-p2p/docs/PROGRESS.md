# Progreso

> Actualizado: 2026-10-15 (noche). Créditos hasta el 2026-11-04.

## Estado en el proyecto real (Supabase `SpeakingApp`, eu-central-1)

| Pieza | Estado |
|---|---|
| Migraciones aplicadas | `baseline_schema`, `rules_helpers_onboarding`, `rules_sessions`, `dev_access_and_internal_token`, `security_advisor_fixes` |
| **Pendientes: las aplica Alfonso en el SQL Editor** | `rules_matchmaking_agenda`, `rules_crons_accounts`, `crons` → pegar `apps/backend/supabase/manual/apply_pending_2026-10-15.sql` (D-026). Sin ellas fallan matchmaking, agenda, borrado de cuenta y crons |
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
| 6. Acceso y monetización | 🟡 | Elegibilidad en servidor; "todos pagan" (D-020). Paywall/RevenueCat/App Open Ad ⏸️ |
| 7. Contenido completo, grabación, cuenta | 🟡 | Perfil (exámenes hechos, grabaciones con días restantes, editar), Ajustes (estado de suscripción, eliminar cuenta con contraseña + frase, D-027). Falta: reproductor de grabaciones, 4 exámenes más por nivel, Términos/Privacidad (textos) |
| 8. Pulido | ⬜ | |

## Cómo se verifica hoy

```bash
# Contenido + funciones (Deno)
deno test --allow-read --allow-env scripts/content apps/backend/supabase/functions/_shared
deno check apps/backend/supabase/functions/*/index.ts
# SQL (Postgres ≥15 con el shim de Supabase)
PGHOST=... PGUSER=postgres apps/backend/supabase/tests/run-plain.sh
# App
cd apps/mobile && flutter analyze && flutter test
```

Resultado en esta sesión: 17 tests Deno ✅, 5 ficheros SQL ✅, **50 tests Flutter ✅** (también con `TZ=Europe/Madrid`), `flutter analyze` y `deno check` limpios. El script del SQL Editor se probó en Postgres local (aplica, registra la versión, se niega a repetir).

## Lo que NO está verificado contra el sistema real

- Las tres migraciones pendientes en Supabase (ver arriba) y, por tanto, el flujo E2E de agenda/matchmaking/borrado contra el servidor.
- La app en un dispositivo Android/iOS (aquí no hay SDK de Android) y una llamada real entre dos móviles.
- LiveKit (`UpdateParticipant`, Egress): fixtures escritos a partir de la documentación.

## Stubs y mocks activos

| Qué | Por qué | Cómo se quita |
|---|---|---|
| Lector silencioso | No hay TTS | Proveedor de TTS + subir audio a R2 |
| Fotos como recuadros | No hay imágenes | Generar/seleccionar fotos y anotar licencias |
| Push (`sendPush` "not configured") | Sin Firebase | Proyecto Firebase + `FCM_SERVICE_ACCOUNT_JSON` |
| Grabaciones sin botón de reproducir | Falta un paquete de audio | Añadir reproductor (p. ej. `just_audio`) usando `media-view-url {recording}` |
| Suscripción solo informativa | RevenueCat aplazado | SDK + webhook (ya escrito) |

## Siguiente paso

1. **Alfonso:** pegar `apps/backend/supabase/manual/apply_pending_2026-10-15.sql` en Supabase › SQL Editor › Run, y borrar el usuario de prueba sin confirmar.
2. Yo: comprobar migraciones/advisors, prueba E2E por HTTP (crear oferta, aceptar, confirmar, entrar, borrar cuenta) y vaciar `config-check`.
3. Probar la app en dos móviles (llamada, lobby, examen sincronizado).
