---
tags: [invariante, grasp, voz, voice-service]
---

# Voz (VoiceService)

> Skill origen: `.claude/skills/voice-service/SKILL.md`. Se activa al tocar la capa de audio: la interfaz `VoiceService`, los adapters o las pantallas `features/rooms` y `features/calls`. Decisión que la gobierna: [[0033-voiceservice-no-decide-quien-habla|ADR 0033]].

## Contrato de la interfaz (enmendado por el ADR 0033)

En `apps/mobile/lib/core/voice/`. `LiveKitEngine` es el **único** fichero que importa `livekit_client`, y `voice_providers.dart` el único sitio donde se elige el adaptador.

- `join(roomId)`: pide el token a `room-voice-token` y se conecta. Nunca publica micrófono por sí solo.
- `leave()`.
- `refreshPermissions()`: vuelve a pedir el token **sin reconectar**.
- `setMicrophoneEnabled(bool)`: silenciarse a uno mismo, y solo con permiso del servidor.
- `setIncomingAudioEnabled(bool)`: dejar de oír la sala durante una llamada ([[0039-una-llamada-silencia-la-sala-sin-sacarte|ADR 0039]]).
- *Streams*: `connectionState`, `canSpeak` (lo que el **servidor** permite), `microphoneEnabled` y `activeSpeakers`.

**No existen `mute(userId)` ni `promoteToSpeaker(userId)`**: el cliente no tiene ningún método que cambie lo que otra persona puede hacer.

## Reglas

1. Ninguna pantalla importa un SDK de proveedor; solo hablan con `VoiceService`.
2. **Validar antes de emitir el token no basta**: un token de LiveKit sigue valiendo hasta que se revoca. Invariante: quien puede publicar en LiveKit es siempre un subconjunto de los `host`/`speaker` vivos de la base. Sube permisos: base → LiveKit. Baja permisos: LiveKit → base. Cierra: base → LiveKit. La reconciliación **solo quita**.
3. Tope del escenario: anfitrión + 2 hablantes ([[0035-escenario-anfitrion-mas-dos-hablantes|ADR 0035]]), contado en la transacción de `room-actions`.
4. Una llamada que se queda sin minutos **la corta el servidor** (`cut_at` + `room-lifecycle-cron`): el token solo vale para la primera conexión.
5. El token se pide con el cliente **del usuario**, nunca con `service_role` (el RPC usa `auth.uid()`).
6. La sala funciona sin voz: si LiveKit no conecta, el chat y la lista de participantes siguen.

## Trampas de LiveKit verificadas contra el servidor real

- `UpdateParticipant` **reemplaza** el `permission` entero: mandar solo `canPublish: false` quita también `canSubscribe`. Siempre se manda el conjunto completo. Y solo un 404 significa «no estaba».
- La API responde en **snake_case** (`can_publish`); los webhooks llegan en camelCase. Un fixture escrito en camelCase dejó la reconciliación ciega en producción con la suite en verde.
- **Para el servidor, reconectar es caerse**: dispara `participant_left` y el webhook saca de la sala a esa persona. Nada que cambie permisos reconecta.
- `ListRooms` tarda unos segundos en listar una sala recién creada: una regla «sin sala en LiveKit → caída» necesita margen.
- Apilar una pantalla sobre la sala no puede desmontarla, o el `voiceServiceProvider` (`autoDispose`) corta la voz. El doble de test tiene que copiar el `onDispose` del proveedor real.

Arneses de prueba con dos dispositivos: `apps/backend/scripts/voice-e2e/` (incluye `lk-watch.mjs`, que observa `can_publish` en vivo) y `calls-e2e/`.

Ver también: [[Edge-Functions-y-reglas-de-negocio]], [[UI-Flutter-y-producto]].
