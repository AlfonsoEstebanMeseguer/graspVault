# Progreso

> Actualizado: 2026-10-15. Créditos hasta el 2026-11-04.

## Estado por hito

| Hito | Estado | Notas |
|---|---|---|
| 0. Setup | ✅ Hecho | Scaffold Flutter, CI (`.github/workflows/speaking-p2p.yml`), lints, i18n ES/EN, tema claro/oscuro, VAULT_NOTES |
| 1. Auth y onboarding | 🟡 Backend hecho, app pendiente | `svc_onboarding_complete` (edad ≥14 en el camino de escritura, username único, lápida del trial), `onboarding-complete`, avatar en R2 (`avatar-upload-url` + `avatar-confirm` con magic bytes). Falta: pantallas de login/onboarding y Google Sign-In nativo → **necesita credenciales** |
| 2. Motor del examen offline | ✅ Hecho (sin audio real) | Esquema Zod + validador, 1 examen por nivel, 3 diagramas, línea temporal TS/Dart con golden, pantallas de las 4 partes + feedback + abandono, cronómetro y "Ver texto" conmutables, compañero simulado. El lector es **silencioso** hasta que exista el TTS |
| 3. Llamada y sesión sincronizada | 🟡 Backend hecho | Máquina de estados en SQL con tests, `session-actions`, mic por `canPublish`, webhook de LiveKit (presencia, gracia de 60 s), grabación con Egress. Falta: `VoiceService` + `LiveKitEngine` en la app, lobby, reloj alineado con el servidor, segundo plano |
| 4. Matchmaking en vivo | 🟡 Backend hecho | FIFO atómico por nivel, latido, elegibilidad en servidor, `hasOpenMeeting` para la ventana de 15 s. Falta: pantallas |
| 5. Agenda | 🟡 Backend hecho | Ofertas (máx. 2), aceptar, modificar, confirmar, solapes, cancelar, entrar, crons de aviso/no-show/expiración, chat con RLS. Falta: pantallas y push en la app |
| 6. Acceso y monetización | 🟡 Backend hecho | Elegibilidad, consumo del trial al empezar la Parte 1, webhook de RevenueCat idempotente. Falta: paywall, SDK de RevenueCat, App Open Ad |
| 7. Contenido completo | ⬜ | Bloqueado por decisión (REVIEW R2) y por el proveedor de TTS |
| 8. Pulido | ⬜ | Pendiente: el diagrama de burbujas se solapa un poco en pantallas estrechas |

## Cómo se verifica hoy

```bash
# Contenido + funciones (Deno)
deno run --allow-read scripts/content/validate.ts
deno test --allow-read --allow-env scripts/content apps/backend/supabase/functions/_shared
deno check apps/backend/supabase/functions/*/index.ts

# SQL (Postgres ≥15 con el shim de Supabase)
PGHOST=... PGUSER=postgres apps/backend/supabase/tests/run-plain.sh

# App
cd apps/mobile && flutter analyze && flutter test
# Práctica sin backend, saltando a la Parte 3 del B2:
flutter run   # y navegar a /practice/B2?at=390800
```

Resultado en esta sesión: 16 tests Deno ✅, 4 ficheros SQL ✅ (con 3 mutaciones comprobadas), 15 tests Flutter ✅, `flutter analyze` sin avisos, `deno check`/`deno lint` limpios. Capturas reales (build web temporal) en `docs/img/`.

## Lo que NO está verificado contra el sistema real (no es "hecho" según el método)

- Migraciones en un Supabase real (`supabase db reset`): solo en Postgres 16 con un shim de `auth`. pg_cron/pg_net/Vault no se han ejecutado.
- Edge Functions desplegadas: solo `deno check` y tests de piezas puras.
- LiveKit (`UpdateParticipant`, Egress, webhook): fixtures escritos a partir de la documentación; el vault avisa de que **el fixture tiene que copiarse de una respuesta real**.
- La app en un dispositivo Android/iOS (aquí no hay SDK de Android).

## Stubs y mocks activos

| Qué | Por qué | Cómo se quita |
|---|---|---|
| Lector silencioso (`SilentReaderPlayer`) | No hay TTS ni CDN | Definir proveedor de TTS, generar audio, `CONTENT_CDN_URL` |
| Fotos como recuadros con su id | No hay imágenes | Generar/seleccionar fotos y anotar licencias en `content/LICENSES.md` |
| Push (`sendPush` falla con "not configured") | Sin `FCM_SERVICE_ACCOUNT_JSON` | Proyecto Firebase |
| App sin backend = modo práctica | Sin `SUPABASE_URL` | `env/dev.json` con `--dart-define-from-file` |

## Siguiente paso

1. Que confirmes las decisiones de REVIEW R1 (edad/moderación) y D-001 (repo propio).
2. Crear los servicios (ver `docs/SETUP.md`) y conectar el MCP de Supabase para aplicar y auditar las migraciones contra el proyecto real.
3. Hito 1 en la app: login con Google + onboarding según los bocetos.
