---
tags: [decision, grasp, producto, salas]
aliases: ["ADR 0032"]
---

# 0032 — El feed de salas no se personaliza: una sola lista, ordenada por actividad

Enmienda al documento maestro, fijada **antes** de implementar la Fase 5 (sin código todavía). El feed de salas no reutiliza el scoring de afinidad de [[0007-bloque2-sin-ui-de-feed]]: con pocas salas simultáneas al arrancar, cualquier ranking personalizado "esconde" en vez de repartir visibilidad — y una sala que nadie ve muere sola.

**Decisión**: una sola lista igual para todos, ordenada por `last_activity_at` (columna que el cron de ciclo de vida necesita de todas formas). El scoring no queda huérfano: sigue usándolo `connect-feed`. Deja abierta y anotada una tensión con la moderación futura (reputación baja ya no puede "hundir" una sala en un ranking que no existe).

[Fichero original](../../docs/decisions/0032-el-feed-de-salas-no-se-personaliza.md)
