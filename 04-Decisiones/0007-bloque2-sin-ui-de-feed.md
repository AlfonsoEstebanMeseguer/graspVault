---
tags: [decision, grasp, producto, planificacion, matching]
aliases: ["ADR 0007"]
---

# 0007 — El Bloque 2 construye el motor de emparejamiento, no la pantalla

El Bloque 2 pedía un `match-feed` que devolviera salas recomendadas y perfiles sugeridos, pero las salas no existen hasta la Fase 5 y un perfil sugerido no tiene ninguna acción posible todavía (seguir llega en Bloque 3, mensajería en Fase 4).

**Decisión**: el algoritmo de afinidad se escribe como función pura con tests, sin pantalla. Se despliega en tres tiempos reutilizando el mismo scoring: Bloque 2 (scoring puro), Bloque 3 (`match-feed` sobre perfiles + "seguir"), Fase 5 (mismo scoring sobre salas — aunque [[0032-el-feed-de-salas-no-se-personaliza]] luego descarta aplicarlo ahí).

[Fichero original](../../docs/decisions/0007-bloque2-sin-ui-de-feed.md)
