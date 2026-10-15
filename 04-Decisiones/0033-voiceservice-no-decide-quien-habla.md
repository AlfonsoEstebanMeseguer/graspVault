---
tags: [decision, grasp, voz, seguridad]
aliases: ["ADR 0033"]
---

# 0033 — `VoiceService` no decide quién habla: el cliente pide token, el servidor da y quita permisos

Enmienda a la Sección 14 del maestro, fijada **antes** de la Fase 6 (2026-10-06) y luego implementada. La interfaz original tenía `mute(userId)` y `promoteToSpeaker(userId)`: el cliente podía cambiar lo que **otra** persona puede hacer.

**Decisión**: el cliente no tiene ningún método que afecte a otro. Se quedan `join`/`leave`, `setMicrophoneEnabled` (silenciarse a uno mismo) y tres *streams* (`connectionState`, `canSpeak`, `activeSpeakers`). Conceder la palabra es `room-actions`, con el tope dentro de la transacción.

**Lo transferible**: un permiso que vive en un sistema externo (el `canPublish` de LiveKit) no se retira cambiando la base, porque el token emitido sigue valiendo. Lo que **sube** permisos va base → externo; lo que los **baja**, externo → base; y la reconciliación solo quita. Un fallo a medias deja menos permiso del debido, nunca más. Ver [[Voz]].

[Fichero original](../../docs/decisions/0033-voiceservice-no-decide-quien-habla.md)
