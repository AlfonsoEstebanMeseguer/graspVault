---
tags: [decision, grasp, producto, mensajeria]
aliases: ["ADR 0029"]
---

# 0029 — Cancelar una solicitud enviada no existe

Decisión puramente documental: un diagrama de la spec dibujaba una transición ("A cancela → NONE") que ninguna `RN-xx` respaldaba y que nunca se implementó. Las tres preguntas que abriría (¿vuelve a NONE y permite saltarse `RN-07`? ¿devuelve el cupo antispam? ¿lo nota el receptor?) no tienen respuesta sin romper algo que ya funciona.

**Decisión**: no existe esa acción; se retira del diagrama. `RN-28` (borrar el mensaje propio) ya cubre la necesidad real. Ejemplo literal del principio "un diagrama que promete un mecanismo hace que nadie compruebe si existe" (CLAUDE.md).

[Fichero original](../../docs/decisions/0029-cancelar-una-solicitud-enviada-no-existe.md)
