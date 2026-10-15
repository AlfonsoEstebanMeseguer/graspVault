---
tags: [decision, grasp, seguridad, edge-functions, crons]
aliases: ["ADR 0011"]
---

# 0011 — Token dedicado (comparado por hash) para autenticar crons internos

`media-gc-cron` se autenticaba con la `service_role key` vía Vault, pero Supabase cambió el formato de esa variable en producción sin avisar y el cron devolvió 401. Diagnosticado comparando SHA-256 sin ver el valor del secreto.

**Decisión**: generar un token dedicado de 32 bytes en Vault por entorno; la función solo conoce su SHA-256 (`requireInternalCaller`), compara en tiempo constante y falla cerrado. `verify_jwt = false`. La `service_role key` se borra de Vault tras el cambio.

Precedente raíz del principio "ningún secreto se copia a mano si se puede copiar un hash" (CLAUDE.md, Principios generales) y del punto 11c de `db-schema`.

[Fichero original](../../docs/decisions/0011-token-dedicado-para-crons-internos.md)
