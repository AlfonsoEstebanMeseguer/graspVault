---
tags: [decision, grasp, seguridad, mensajeria]
aliases: ["ADR 0025"]
---

# 0025 — La fila 4 del input se emite constante

Hallazgo: para una solicitud de mensaje recibida, `can_send: false` solo puede provenir de un bloqueo (comprobado por eliminación lógica) — así que esos campos actuaban de oráculo pasivo de bloqueo, violando el invariante "ninguna respuesta revela un bloqueo, ni por texto ni por forma". No lo detectaron los tests porque cada fila se probó aislada, no contra su vecina.

**Decisión**: cuando `request_actions` es `true`, el input se emite siempre constante (`can_send: true, input_notice: null, messages_left: null`), resuelto antes de llamar al evaluador de límites. Se arregla la vista, no el enforcement — extiende [[0022-un-solo-texto-para-el-input-inerte]] de texto a forma. No cierra el oráculo activo (intentar enviar sigue fallando) — eso lo asume [[0028-el-bloqueo-es-detectable-por-quien-lo-sufre]].

[Fichero original](../../docs/decisions/0025-la-fila-4-del-input-se-emite-constante.md)
