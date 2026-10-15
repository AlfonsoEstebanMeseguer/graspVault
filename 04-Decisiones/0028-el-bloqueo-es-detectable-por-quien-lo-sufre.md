---
tags: [decision, grasp, seguridad, producto, mensajeria]
aliases: ["ADR 0028"]
---

# 0028 — El bloqueo es detectable por quien lo sufre, y se deja de prometer lo contrario

Tres deudas pendientes de la Fase 4 (canal de tiempo, forma del input, invisibilidad mutua) resultan ser la misma pregunta: cuánto puede deducir un bloqueado. Las "soluciones" propuestas eran peores que el problema — en especial descartar mensajes en silencio, que miente durante meses a una persona vulnerable.

**Decisión y segunda enmienda a `RN-23`**: la regla protege el **contenido** de las respuestas, no la **capacidad de actuar** — un oráculo activo (una acción que falla) es inherente al enforcement y no se cierra; solo el oráculo pasivo (campos que no se pintan pero varían) se cierra. Única pieza de código real: rate limit en `connect-tag-lookup` (30/día) para acotar por volumen, no para cerrar el canal. Complementa [[0027-el-bloqueo-deja-de-ser-irreversible]] y [[0025-la-fila-4-del-input-se-emite-constante]].

[Fichero original](../../docs/decisions/0028-el-bloqueo-es-detectable-por-quien-lo-sufre.md)
