---
tags: [decision, grasp, schema, producto, mensajeria]
aliases: ["ADR 0021"]
---

# 0021 — Mensajería sin confirmación de lectura

`RN-31` prohibía tajantemente cualquier "visto"/`read_at`, pero la columna estaba declarada vigente en tres documentos — el más peligroso siendo el ejemplo de `create table` dentro de la skill `db-schema`, que se **copia** literalmente al escribir la migración real.

**Decisión**: `read_at` no existe, nunca. En su lugar, `conversation_states.unread_count` es una fila **por usuario** con RLS propia — el emisor no puede leer el contador del receptor porque es una fila distinta, no por disciplina del endpoint. Lección general de método: "un ejemplo desactualizado dentro de una skill no es documentación vieja, es una implementación futura equivocada ya escrita y esperando" — mismo patrón que llevó al teléfono filtrado ([[0015-borrar-el-telefono-en-vez-de-esconderlo]]).

[Fichero original](../../docs/decisions/0021-mensajeria-sin-confirmacion-de-lectura.md)
