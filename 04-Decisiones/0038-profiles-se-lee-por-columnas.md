---
tags: [decision, grasp, rls, rgpd]
aliases: ["ADR 0038"]
---

# 0038 — `profiles` se lee por columnas; `language` y `photo_url` se borran

Hallazgo del [[0037-el-perfil-ajeno-se-ve-como-el-propio|ADR 0037]] (2026-10-07). `profiles` tenía `grant select` **de tabla** y una policy `using (true)`: cualquier usuario con sesión podía leer `vip_status`, `reputation_score`, `gifts_received_count`, `language`, `photo_url` y `created_at` de todo el mundo. Era exactamente lo que la vista `public_profiles` declaraba no publicar. Fue el punto 9b **por segunda vez en la misma tabla**: en agosto se borró el teléfono, pero el `grant` de tabla siguió ahí.

**Decisión**: `revoke select` de tabla y `grant select (<columnas públicas>)`. Antes se enumeraron los consumidores (app, Edge Functions, SQL, Realtime). `language` y `photo_url` no los leía nadie, así que se **borran** (punto 9c).

**Lo transferible**: arreglar el síntoma (el teléfono) sin cerrar la causa (el `grant` de tabla) deja la puerta abierta al siguiente dato. Una vista que enumera no protege nada si la tabla base se lee entera.

[Fichero original](../../docs/decisions/0038-profiles-se-lee-por-columnas.md)
