---
tags:
  - arquitectura
  - api
  - grasp
---

# Contratos de API — Edge Functions reales

Fuente completa: `docs/api-contracts.md` (mitad inventario, mitad especificación — la columna
**Estado** distingue una cosa de la otra). Esta nota es el resumen por estado, cruzado contra el
filesystem real (`apps/backend/supabase/functions/`, 2026-10-13).

> [!info] Tres estados, no dos
> `desplegado` = hay código y está en producción (verificar con `list_edge_functions`, nunca con la
> fecha de esta tabla). `pendiente` = la carpeta existe con solo `README.md`. `planificado` = ni
> siquiera hay carpeta — el nombre está reservado por una decisión.

## Con código (41 carpetas; 39 con `index.ts`, revisado contra el filesystem el 2026-10-13)

Según `docs/api-contracts.md`, todas las que tienen código están desplegadas en producción. La versión
viva de cada una se comprueba con `list_edge_functions`, nunca con esta tabla.

| Fase | Funciones | Responsabilidad |
|---|---|---|
| Bloques 1–3 | `onboarding-complete` / `onboarding-catalogs` / `onboarding-get`, `profile-update` / `profile-tag-rotate`, `account-delete` | Onboarding, perfil y borrado de cuenta con reautenticación (ADR 0016) |
| Bloque 3 | `profile-photo-upload-url` / `profile-avatar-set` / `profile-photo-view-url`, `media-gc-cron` / `media-reconcile-cron` / `ops-digest-cron` | Foto/avatar sobre R2 y crons de limpieza, reconciliación y alertas |
| Fase 4 | `connect-feed` / `connect-tag-lookup` / `connect-dismiss`, `messaging-*` (6), `follow-toggle`, `block-create` / `block-remove`, `report-create` | Conectar, mensajería 1:1 de texto, seguir, bloqueo y reporte |
| Fase 5 | `rooms-feed`, `room-actions`, `room-detail`, `room-lifecycle-cron` | Salas sin personalizar (ADR 0032); aforo y escenario en Postgres; cierre automático |
| Fase 6 | `room-voice-token`, `livekit-webhook` | Token de voz y eventos de LiveKit (ADR 0033) |
| Fase 7 | `call-actions`, `call-voice-token` | Llamadas privadas con cupo diario cortado por el servidor |
| Saldo de voz | `ad-reward-ssv` | Minutos por anuncio con recompensa, tras verificar la firma SSV de AdMob (ADR 0041) |
| Fase 10a | `moderation-enforce`, `account-status`, `sanction-appeal`, `panic-trigger`, `welfare-signal` | Moderación con revisión humana, modo restringido, apelación y pánico sin audio (ADR 0043) |

La Fase 9a (VIP sin cobro) no tiene función propia: `private.vip_grant` / `vip_revoke` son SQL privado.

## Pendientes (solo `README.md`, sin código)

| Función | Fase |
|---|---|
| `gift-send` | Fase 8, pospuesta (ADR 0042) |
| `iap-webhook` | Fase 8 / 9b, pospuesta (ADR 0042) |

`reputation-recalc-cron` ya no existe: la reputación salió de la Fase 10 ([[0043-moderacion-con-revision-humana|ADR 0043]]).
## Lo que no tiene Edge Function, a propósito

El perfil ajeno **no** tiene Edge Function dedicada (ni `public-profile`, ni similar): todo lo que
necesita leerse de otra persona sale por PostgREST directo (`profiles` **por columnas** desde el ADR 0038, `user_badges`) y la vista `public.public_profiles` (deriva la edad sin exponer `birth_date` — ADR
0026). Criterio aplicado: se mira primero qué `GRANT` hay, y solo sube a Edge Function lo que
necesite `service_role` para existir.

## Aviso de método (de `docs/api-contracts.md`, ADR 0019)

Que una fila diga "desplegado en producción" significa que **hubo** un despliegue, no que sea el
código de hoy. Cuatro funciones llegaron a correr meses con código viejo mientras la tabla las daba
por actualizadas. La única autoridad es `mcp__supabase__list_edge_functions` (versión y fecha reales).

## Ver también

- [[Backend-Supabase-Edge-Functions]]
- [[Vision-general]]
- [[Edge-Functions-y-reglas-de-negocio]]
