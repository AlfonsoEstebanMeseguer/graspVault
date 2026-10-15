---
tags: [decision, grasp, proceso, migraciones]
aliases: ["ADR 0034"]
---

# 0034 — `apply_migration` está permitido; la migración se canoniza en el mismo turno

Regla de proceso (2026-10-06). El MCP de Supabase no registra el `version` del fichero, sino el instante en que se aplica. El 2026-10-04 eso dejó tres versiones en producción sin fichero local; el siguiente `db push` abortó y proponía marcarlas `reverted`, lo que habría perdido un cambio real (`revoke execute on rooms_feed from service_role`). De ahí salió «nunca `apply_migration`», que convertía cada migración en un viaje de ida y vuelta con Alfonso.

**Decisión**: se permite, con procedimiento obligatorio en el mismo turno. El fichero local existe y está probado, se aplica su contenido exacto, se lee el `version` registrado en `supabase_migrations.schema_migrations` y **se renombra el fichero local a ese `version`**. Detalle en el punto 14e de `db-schema`.

**Lo transferible**: el defecto no estaba en la herramienta, sino en no cerrar el ciclo después. Antes de prohibir una herramienta que ahorra trabajo, se busca el paso que falta.

[Fichero original](../../docs/decisions/0034-apply-migration-permitido-con-canonizacion.md)
