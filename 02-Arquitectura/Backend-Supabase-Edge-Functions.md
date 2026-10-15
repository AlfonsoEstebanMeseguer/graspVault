---
tags:
  - arquitectura
  - backend
  - grasp
---

# Backend — Supabase Edge Functions (Deno)

Código en `apps/backend/supabase/functions/<nombre>/`. Verificado por Glob directo al filesystem
(2026-10-04), no solo por la documentación:

## Edge Functions reales (carpetas existentes)

```
_shared/  account-delete/  block-create/  block-remove/  connect-dismiss/  connect-feed/
connect-tag-lookup/  follow-toggle/  gift-send/  iap-webhook/  media-gc-cron/  media-reconcile-cron/
messaging-actions/  messaging-inbox/  messaging-message-actions/  messaging-search/  messaging-send/
messaging-thread/  onboarding-catalogs/  onboarding-complete/  onboarding-get/  ops-digest-cron/
panic-trigger/  profile-avatar-set/  profile-photo-upload-url/  profile-photo-view-url/
profile-tag-rotate/  profile-update/  report-create/  reputation-recalc-cron/  room-actions/
room-lifecycle-cron/  rooms-feed/
```

No todas tienen código: algunas son solo `README.md` (andamiaje del plan de fases, no código muerto).
Estado real función por función: [[Contratos-API]].

**Desalineación docs-vs-código encontrada:** `docs/README.md` (raíz) dice "20 directorios de Edge
Functions, 10 implementadas"; el filesystem real hoy tiene **31** carpetas (30 funciones + `_shared`).
El número de README.md está desactualizado — no sorprende, dado el patrón de "documento histórico con
aviso de vigencia en cabecera" que se repite en `docs/` (ver [[Retroalimentacion-continua]]). La fuente
de verdad real para "está desplegado" nunca es un recuento de carpetas: es `mcp__supabase__list_edge_functions`
contra el proyecto real (ver ADR 0019 y el aviso en `docs/api-contracts.md`).

## Convenciones (invariantes de `.claude/CLAUDE.md` § Backend y reglas de negocio)

- `service_role key` **solo** server-side, nunca embebida en Flutter.
- Validación de input obligatoria en cada función.
- **Idempotencia obligatoria** en `gift-send`, `messaging-send` e `iap-webhook` (clave por evento —
  `messaging-send` usa `idempotency_key` sobre un índice único parcial).
- Reglas de negocio críticas en backend, nunca solo en cliente: anfitrión + 2 hablantes por sala (ADR 0035)
  (`room-actions`, comprobado con `for update` en la misma transacción), minutos de llamada gratuita,
  saldo de monedas.
- Acciones irreversibles (`account-delete`) exigen reautenticación — contraseña **más** frase de
  confirmación, las dos comprobadas en backend, porque un JWT solo prueba que hubo login durante su
  vigencia.

Detalle de precedentes y los puntos numerados de la skill: [[Edge-Functions-y-reglas-de-negocio]].

## Patrón recurrente: `service_role` no implica "sin reglas"

`service_role` tiene `BYPASSRLS`, **no** `BYPASSGRANT` — se salta las policies de fila, nunca los
`GRANT` de tabla. Y un RPC personalizado con `auth.uid()` (como `activity_status`) **no** se puede
llamar con `service_role`: la clave de servicio es un JWT sin `sub`, así que devuelve la respuesta del
anónimo sin dar error. Ver [[RLS-y-permisos]] y [[Edge-Functions-y-reglas-de-negocio]].

## Crons internos

`media-gc-cron`, `media-reconcile-cron`, `ops-digest-cron`, `room-lifecycle-cron`,
`reputation-recalc-cron` — programados con `pg_cron` **desde una migración**, nunca desde
`config.toml` (el CLI ignora esa clave en silencio). Se autentican con un token dedicado (Vault +
SHA-256, patrón `requireInternalCaller`), nunca con `verify_jwt` ni la `service_role key`.

## Ver también

- [[Vision-general]]
- [[Contratos-API]]
- [[Base-de-datos-Postgres]]
