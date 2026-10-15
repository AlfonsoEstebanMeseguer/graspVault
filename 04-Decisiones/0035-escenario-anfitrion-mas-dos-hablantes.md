---
tags: [decision, grasp, voz, salas]
aliases: ["ADR 0035"]
---

# 0035 — El escenario de una sala: el anfitrión + 2 hablantes

Decidido por Alfonso al probar la voz en un móvil real (2026-10-06). «Máximo 2 hablantes» contaba **al anfitrión**, así que en la práctica era anfitrión + 1. El boceto nuevo de la sala dibujaba tres huecos.

**Decisión**: `room_max_speakers()` = 3, contando `host` + `speaker`. El mecanismo no cambia: el tope se cuenta en la transacción que promueve (`for update` sobre `rooms`) y en LiveKit se respeta el orden del [[0033-voiceservice-no-decide-quien-habla|ADR 0033]]. El espejo `MAX_SPEAKERS` de `_shared/rooms.ts` pasa a 3.

**Consecuencia de coste**: más voces son más minutos de participante en LiveKit; el umbral de pago llega antes, y hay que rehacer la cuenta antes de lanzar.

[Fichero original](../../docs/decisions/0035-escenario-anfitrion-mas-dos-hablantes.md)
