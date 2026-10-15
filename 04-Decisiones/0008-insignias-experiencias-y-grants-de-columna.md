---
tags: [decision, grasp, rls, schema, seguridad]
aliases: ["ADR 0008"]
---

# 0008 — Insignias, experiencias concretas y grants de columna en `profiles`

Registra el desacuerdo (CLAUDE.md §0.1) de `audit-leader` frente a lo pedido: `badges` nace como tabla real (no FK a `categories`, que contaminaría el matching); `user_experiences` NO es de lectura pública porque las experiencias concretas son dato del Art. 9 RGPD — cualquiera con JWT podría volcar crisis personales de toda la base.

**Hallazgo no solicitado y más grave**: `profiles` solo tenía `GRANT` de tabla, así que cualquier usuario podía autoconcederse `vip_status`, `level`, `xp` vía PATCH directo — el invariante de CLAUDE.md estaba roto desde el Bloque 1. Se corrige con `revoke update` + `grant update` por columnas. Origen del punto 9 de la skill `rls-security`.

[Fichero original](../../docs/decisions/0008-insignias-experiencias-y-grants-de-columna.md)
