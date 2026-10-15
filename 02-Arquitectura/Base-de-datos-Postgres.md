---
tags:
  - arquitectura
  - base-de-datos
  - postgres
  - grasp
---

# Base de datos — Postgres (vía Supabase)

Migraciones en `apps/backend/supabase/migrations/` — **única fuente de verdad** del esquema (más que
`docs/db-schema.md`, que es un espejo mantenido a mano y puede quedarse atrás).

## Convenciones

- `snake_case` en todo.
- `id uuid primary key default gen_random_uuid()` salvo que se indique otra cosa.
- **Los timestamps NO son columnas por defecto**: `created_at`/`updated_at` solo se añaden si algo los
  lee. `updated_at` exige un trigger (`public.set_updated_at()` es la función reutilizable) o la
  columna miente (queda siempre igual a `created_at`).
- Migraciones con rollback documentado.
- **RLS activado en todas las tablas sin excepción.** Detalle del invariante y sus precedentes:
  [[RLS-y-permisos]].

## Patrón recurrente: dos tablas de perfil

`profiles` (pública, lectura de cualquier `authenticated`) y `profiles_private` (país, género,
`birth_date`, categorías de apoyo — dato de salud, Art. 9 RGPD). La frontera entre público y sensible
es **estructural** (tabla separada), no una policy — porque RLS filtra filas, nunca columnas, así que
una sola tabla con policies distintas por columna no es posible directamente.

## Patrón recurrente: tablas sin ningún `GRANT` para el cliente

`conversations`, `connect_dismissals`, `connect_impressions`, `connect_feed_runs`,
`connect_tag_lookups` — ninguna tiene policies ni grants para `authenticated`/`anon`. Solo
`service_role` las toca. Es la regla por defecto (ver [[Esquema-y-migraciones]] punto 6b): una tabla
nueva nace **sin** permisos, y si solo la tocan Edge Functions, se queda así.

## Patrón recurrente: fecha dentro de la clave primaria

`connect_impressions`, `connect_feed_runs`, `connect_tag_lookups` meten la fecha de caducidad **dentro
de la PK**, de forma que la lógica de expiración es automática (sin cron, sin columna de estado) salvo
la purga física periódica. Patrón elegante para cualquier cupo/tope que se reinicia por día.

## Squash de migraciones (2026-08-16)

Las primeras 19 migraciones se consolidaron en 3 (`baseline_schema`, `baseline_crons`,
`baseline_seed_catalogs`), con la equivalencia probada por diff contra un `pg_dump` de referencia, no
afirmada. Condiciones bajo las que un squash es aceptable (ver [[Esquema-y-migraciones]] y
`docs/decisions/0017-consolidar-las-migraciones-en-tres.md`): proyecto sin publicar, sin otros entornos
con historial propio aplicado.

## Ver también

- [[Vision-general]]
- [[RLS-y-permisos]]
- [[Esquema-y-migraciones]]
- [[Contratos-API]]
