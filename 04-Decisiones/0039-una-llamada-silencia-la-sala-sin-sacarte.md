---
tags: [decision, grasp, voz, llamadas]
aliases: ["ADR 0039"]
---

# 0039 — Una llamada silencia la sala sin sacarte de ella

Decidido por Alfonso tras la prueba con dos dispositivos de la Fase 7 (2026-10-08). La spec decía «no se puede estar en una sala y en una llamada a la vez»: a quien estaba en una sala no le sonaba la llamada, y contestar te sacaba de ella.

**Decisión**: a quien está en una sala **le suena la llamada**. Mientras suena y mientras dura, la sala se silencia para esa persona y ella para la sala, sin salir. Al colgar, todo vuelve como estaba, micrófono incluido. Los demás solo la ven silenciada: no hay indicador de «en una llamada». Lo que sigue impedido es entrar en una sala **nueva** con una llamada viva (trigger `room_participants_not_in_call`). `VoiceService` gana `setIncomingAudioEnabled(bool)`.

**Lo transferible**: la regla «exclusivo» de una spec se valida con dos dispositivos reales antes de darla por buena.

[Fichero original](../../docs/decisions/0039-una-llamada-silencia-la-sala-sin-sacarte.md)
