---
tags: [decision, grasp, schema, migraciones, produccion]
aliases: ["ADR 0019"]
---

# 0019 — Reconciliar producción sin reconstruirla

Al conectar el MCP de Supabase se descubrió que producción nunca aplicó el baseline ni las migraciones posteriores: `phone_number` seguía vivo y legible (H-S-01 y H-SV-03 activos en producción pese a que el repositorio los daba por cerrados desde [[0015-borrar-el-telefono-en-vez-de-esconderlo]]), y `handle_new_user` en producción no coincidía con ningún commit de git.

**Decisión**: reconciliar con una migración nueva en vez de reconstruir (Camino A de [[0017-consolidar-las-migraciones-en-tres]]) porque producción ya tenía datos reales (3 cuentas, fotos, secretos de Vault) que reconstruir destruiría. Se verifica por comparación de digests, no se asume. Destapó además que varias Edge Functions vivas en producción llevaban meses por detrás del código — origen de la regla "un `db push` alinea el esquema, NO el código que lo usa" (`edge-functions`, punto 10).

[Fichero original](../../docs/decisions/0019-reconciliar-produccion-sin-reconstruirla.md)
