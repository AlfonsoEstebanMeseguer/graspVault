---
tags: [decision, grasp, producto, mensajeria]
aliases: ["ADR 0023"]
---

# 0023 — El ignorar sobrevive a los mensajes 2..5 del emisor

Dos pasos del mismo plan se contradecían: la entrega de un mensaje reaparece la conversación (`RN-27`, pensado para borrado de historial) vs. `ignore` como estado terminal (`RN-06`/`RN-07`). Aplicados literalmente, un emisor ignorado podía resucitar la conversación en el buzón del receptor con solo seguir escribiendo (tiene 5 mensajes disponibles).

**Decisión**: en una conversación `ignored`, la entrega NO toca `hidden` ni `unread_count` del receptor. Ampliado el 2026-08-28: el propio `ignore` pone el contador a cero (el primer mensaje, previo al ignorar, dejaba un residuo). Vive en el trigger de BD, no en la Edge Function, para cubrir todo camino de escritura.

[Fichero original](../../docs/decisions/0023-el-ignorar-sobrevive-a-los-mensajes-pendientes.md)
