---
tags: [decision, grasp, schema, ops, matching]
aliases: ["ADR 0030"]
---

# 0030 — El tope del pool de Conectar se queda, y pasa a vigilarse solo

`MAX_POOL = 1000` se mantiene sin cambios — con 3 usuarios en producción no hay datos para justificar otro número. En vez de un comentario-recordatorio (que nadie revisa), `ops-digest-cron` calcula diariamente la cobertura (`MAX_POOL / perfiles elegibles`) y avisa por correo si baja de 0.5.

Ejemplo del principio "mecanismo sin puerta de entrada" aplicado a vigilancia: un número que hay que revisar "cuando la base crezca" depende de la memoria de alguien, así que se mueve a un canal que ya existe y se emite siempre (no solo ante incidencia).

[Fichero original](../../docs/decisions/0030-el-tope-del-pool-de-conectar-se-vigila-en-vez-de-adivinarse.md)
