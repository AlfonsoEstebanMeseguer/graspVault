---
tags: [decision, grasp, schema, migraciones]
aliases: ["ADR 0017"]
---

# 0017 — Consolidar las 19 migraciones en 3

Squash explícito pedido por el usuario, excepción documentada a la prohibición general de tocar migraciones aplicadas — válido solo porque producción tenía 1 perfil y 0 fotos. Se reparten en baseline schema / crons / seed catalogs, escritas idempotentes, y se prueba equivalencia por diff real (`pg_dump`, grants, policies) antes de borrar las 19 viejas.

**⚠️ Enmendado el 2026-08-17 por [[0018-display-name-obligatorio]]**: al fundir un cambio de esquema dentro del baseline, el "Camino B" (reconciliar sin reconstruir) queda **prohibido** — la prueba de equivalencia ya solo describe el commit del squash, no el fichero actual. Lección: un baseline con prueba de equivalencia adosada caduca en el primer cambio que se le funda encima.

[Fichero original](../../docs/decisions/0017-consolidar-las-migraciones-en-tres.md)
