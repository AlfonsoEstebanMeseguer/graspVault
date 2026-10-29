# Plan de implementación · Moderación, fase 1: recoger pruebas (sin sanciones)

> 2026-10-29 · Aprobado por Alfonso (respuestas en `2026-10-29-reportes-sabotaje.md` §9: umbrales y escala bien, revisa él desde Supabase Studio, sí al hash del email de las cuentas bloqueadas, empezar por la fase 1).
> **La fase 1 no sanciona a nadie.** Solo guarda pruebas durante 2–4 semanas para calibrar los umbrales de la fase 2. Reportar y bloquear (D-044) siguen igual.

## Objetivo

Que cada sesión deje un rastro objetivo, sin audio:
1. **Registro de eventos** (`session_events`): entrar y salir, «Listo», consentimiento de grabación, cambios de estado (cada parte, fin y abandono con motivo), **cada** control del líder, silenciarse a uno mismo y publicar o retirar el micro.
2. **Tiempo de voz por tramo** (`session_talk_stats`): cuánto habló A, cuánto B y cuánto a la vez en cada segmento del examen (también en la sala de espera y el feedback), con qué micros permitía el servidor.
3. **Reportes más fiables:** motivos nuevos de sabotaje, comprobación de que quien reporta estaba en la sesión y un reporte por persona y sesión.

## 1. Base de datos — migración `…_moderation_evidence.sql`

| Pieza | Detalle |
|---|---|
| `public.session_events` | `id`, `session_id` (→ `exam_sessions`, `on delete cascade`), `user_id` (puede ser nulo, `on delete set null`), `kind`, `state` (la parte en ese momento), `at`, `data jsonb`. Índice `(session_id, at)`. RLS activada **sin políticas**: ningún cliente la lee. |
| `public.session_talk_stats` | `session_id`, `reporter_id` (quién lo midió), `seg_index` (−1 fuera del examen), `started_at`, `state`, `phase` (`reader`/`speak`/nulo), `paused`, `mic_a`, `mic_b`, `window_ms`, `speech_a_ms`, `speech_b_ms`, `overlap_ms`, `received_at`. Clave única `(session_id, reporter_id, seg_index, started_at)`, para que un reenvío no duplique. Comprobaciones: `0 ≤ speech ≤ window ≤ 20 min` y `overlap ≤ min(speech_a, speech_b)`. RLS **sin políticas**. |
| Trigger `private.log_session_changes` | `after update` en `exam_sessions`. Compara `old` con `new` y apunta `joined`, `left` (desconexión), `rejoined`, `ready`, `recording_consent`, `state` (`{from, to, reason, by}`) y `control` (el `last_control` nuevo). No toca `private.ctl_apply` ni el contrato Dart/SQL de los controles (`control-golden.json`). |
| `public.svc_session_log(sesión, usuario, kind, data)` | Solo `service_role`. Admite `self_mute`, `track_published` y `track_unpublished`, solo de participantes y como mucho 500 por persona y sesión. |
| `public.svc_session_talk_stats(sesión, usuario, ventanas jsonb)` | Solo `service_role`. Participante obligatorio y lotes de 1 a 20 ventanas. Revisa límites, que el inicio caiga entre la creación de la sesión y ahora + 1 min, y que el estado sea válido. `on conflict do nothing`. Máximo 1.000 filas por persona y sesión. Devuelve cuántas guardó. Una ventana imposible → `bad_stats`. |
| `user_reports` | Motivos nuevos: `silent`, `quit`, `control_abuse`, `noise`, `mocking`. Índice único parcial `(reporter_id, reported_id, session_id) where session_id is not null`. |
| `report_user` | **Misma firma.** Con `p_session`, quien reporta y el reportado tienen que ser `user_a` y `user_b` de esa sesión (`not_in_session`). Los motivos de sabotaje exigen una sesión. El segundo reporte a la misma persona en la misma sesión no hace nada (sin error, para no romper la app). |
| `svc_cron_housekeeping` | Además: borra eventos y tiempos de voz de sesiones de hace más de 30 días, salvo si hay un reporte abierto sobre la sesión. Devuelve también `evidence`. |

Antes de aplicarla en Supabase: comprobar que no hay reportes duplicados que impidan crear el índice único.

## 2. Edge Functions

- `session-actions` (`schema.ts`):
  - `talk_stats {sessionId, windows[1..20]}`, con un esquema Zod que acota cada campo → `svc_session_talk_stats`;
  - `self_mute {sessionId, muted}` → `svc_session_log`.
- `livekit-webhook`: `track_published` y `track_unpublished` (solo audio) → `svc_session_log`. `participant_joined/left` sigue igual.
- Tests de Deno para los dos esquemas nuevos.

## 3. App

- `domain/session/talk_meter.dart` (lógica pura, con tests): acumula el tiempo de voz de A, de B y a la vez a partir de los cambios de `activeSpeakers` (los calcula el servidor de LiveKit, la identidad es el id de usuario) y corta una ventana en cada cambio de tramo.
- `LiveSession`: el tramo es el de `tickNow` (estado, segmento, pausa y versión de control). Al cambiar, cierra la ventana anterior y la envía con `talkStats`. Las ventanas de menos de 1 s no se envían. Al cerrar la sesión o salir, envía la última. Si un envío falla, no se reintenta: son pruebas, no estado del examen.
- `toggleMute` también avisa al servidor (`self_mute`), sin bloquear el botón.
- Hoja de reportar: los motivos de sabotaje (no habla, se burla, ruido, abandona a propósito, abusa de los controles) solo aparecen con una sesión (sala de espera, examen y feedback). i18n ES/EN.
- Política de privacidad: un párrafo sobre qué se mide (tiempo de voz por turno, sin grabar ni transcribir), para qué y durante cuánto tiempo.

## 4. Verificación

- SQL: nueva suite `11_moderation.sql` (Docker): trigger, validación y reenvío de ventanas, pertenencia y duplicados en `report_user`, permisos (nadie lee las tablas nuevas y `authenticated` no ejecuta `svc_*`) y la purga.
- `deno check` y `deno test` de las funciones; `flutter analyze`; `flutter test`.
- Despliegue (cuando Alfonso lo apruebe): migración con el MCP, revisión del asesor de seguridad y `session-actions` y `livekit-webhook`. En LiveKit, el webhook ya recibe todos los eventos, así que no hay nada que configurar.

## 5. Después (fases 2 y 3, no ahora)

Veredictos automáticos y cola `moderation_queue` para revisar en Studio; avisos; restricciones con caducidad; recursos; grabación retenida mientras haya un caso; y la tabla `banned_identities (email_sha256, banned_at, expires_at)` de 12 meses, que se consulta al registrarse.
