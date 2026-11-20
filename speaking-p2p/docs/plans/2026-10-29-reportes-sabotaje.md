# Reportar y penalizar el sabotaje del examen (análisis, pendiente de aprobación)

> 2026-10-29 · Estado: **propuesta**. No hay nada implementado en el backend. Reportar y bloquear (D-044) siguen funcionando igual.

## 0. Resumen

- **Principio:** nadie recibe una sanción por la palabra de una sola persona. Una sanción automática solo puede salir de **pruebas objetivas que guarda el servidor**. Todo lo subjetivo (burlas, insultos) necesita una revisión humana y, si es posible, la grabación o varios reportes independientes.
- **Pruebas sin audio:** el servidor ya sabe quién se conectó, quién abandonó y en qué parte, y qué hizo el líder. Faltan dos cosas: un **registro de eventos** de la sesión (hoy solo se guarda el *último* control) y **cuánto habló cada uno en cada turno**, en números y sin contenido.
- **Escala:** aviso → 24 h sin emparejamiento en vivo → 7 días sin emparejamiento ni propuestas → bloqueo de la cuenta (este, siempre a mano). Los puntos caducan a los 90 días y siempre se puede recurrir.
- **Implantación en 3 fases:** primero se recogen pruebas sin sancionar a nadie (2–4 semanas para calibrar umbrales), después llegan los avisos y por último las suspensiones y los recursos.

## 1. Qué cuenta como sabotaje

| Motivo nuevo (`reason`) | Ejemplo | ¿Se puede medir? |
|---|---|---|
| `silent` | No habla en sus turnos | **Sí**: tiempo de voz por turno |
| `quit` | Abandona a propósito, una y otra vez | **Sí**: `abort_reason = 'left'`, parte, frecuencia |
| `control_abuse` | El líder Pro salta partes o termina el examen sin motivo | **Sí**: registro de controles |
| `noise` | Música, ruido o hablar encima en las Partes 3–4 | En parte: voz solapada y nivel de audio |
| `mocking` | Se burla, interrumpe para ridiculizar | No: revisión humana |
| `harassment`, `sexual`, `hate`, `minor_safety` (ya existen) | Contenido ofensivo | No: revisión humana, prioridad alta |
| `no_show` (ya existe) | No se presenta a una reunión | **Sí**: `attendance` |

## 2. Pruebas objetivas que puede guardar el servidor

### 2.1 Lo que ya existe
- `exam_sessions`: `joined_*_at`, `disconnected_*_at` (webhook de LiveKit), `aborted_by`, `abort_reason` (`left`, `disconnected`, `no_show`…), el estado en el que se abortó (la parte), `exam_started_at`, `ended_at`, `leader_id`, `control_version` y `last_control` (**solo el último**).
- `exam_history.completed`, `attendance` y los `no_show` de la agenda.
- `peer_ratings`: valoración privada de 1 a 5 (D-042). **No se usa como prueba**: es una opinión y castigar por una nota baja desanimaría a dar feedback sincero.
- La grabación, solo si los dos dieron su consentimiento (30 días en R2).

### 2.2 Lo que habría que añadir
1. **Registro de eventos de la sesión** (`session_events`, solo lo escribe el servidor): entrar, salir y reconectar (webhook), «Listo», consentimiento de grabación, **cada** control del líder (hoy se pisa), abandonar (con la parte y el segundo), silenciarse a uno mismo (hoy no llega al servidor) y publicar o retirar la pista de audio (webhook `track_published` / `track_unpublished`).
2. **Tiempo de voz por segmento** (`session_talk_stats`). Al cerrar cada segmento, cada móvil envía a `session-actions`:
   - su propio tiempo de voz (detector de voz de su micro);
   - el tiempo de voz **que ha recibido** del compañero;
   - el tiempo en que hablaron los dos a la vez (solo en las Partes 3–4 y en el feedback).

   Así cada persona tiene **dos medidas independientes**: la suya y la de su compañero. Si coinciden, la prueba es sólida. Si no coinciden (yo digo que hablé y el otro no me oyó), lo más probable es un problema de red, así que se cruza con las desconexiones y el reporte se queda en «no concluyente». El servidor rechaza valores imposibles: más voz que la duración del segmento, voz en un turno en el que el servidor tenía el micro cerrado, un segmento enviado dos veces o un segmento de otra sesión.
3. **(Fase opcional) Medidor en el servidor:** un agente de LiveKit que se une a la sala sin publicar y mide la voz de cada pista. Es objetivo, no depende de los móviles y no guarda audio, pero cuesta minutos de agente y otro servicio que mantener. Solo merece la pena si el punto 2 se manipula en la práctica.

**Descartado:** grabar siempre «por seguridad». Con usuarios desde 14 años y sin consentimiento de los dos, es desproporcionado (RGPD, art. 5.1.c) y contradice CLAUDE.md §6.

## 3. Cómo se verifica un reporte

Al crearse, cada reporte recibe un **veredicto automático**, que se recalcula al terminar la sesión porque el otro reporte o las estadísticas pueden llegar después:

| Veredicto | Cuándo | ¿Puede sancionar solo? |
|---|---|---|
| `corroborated` | Las pruebas objetivas confirman el motivo (ver tabla) | Sí, hasta 7 días de suspensión |
| `consistent` | ≥ 2 reportes del **mismo motivo**, de personas distintas, en sesiones distintas, en 30 días | No: va a revisión humana con prioridad |
| `unverified` | Un solo reporte sin pruebas | No: solo se cuenta |
| `contradicted` | Las pruebas lo desmienten (p. ej., `silent` cuando las dos medidas dicen que habló el 70 % de sus turnos) | No; cuenta en contra de quien reporta (§5) |

Reglas objetivas propuestas (los umbrales se calibran con los datos de la fase 1):
- **`silent`:** en ≥ 3 turnos propios, las dos medidas dan < 15 % de voz, sin desconexión en esos turnos y sin silenciarse por una pausa.
- **`quit`:** `abort_reason = 'left'` del reportado después de empezar la Parte 1, **y** ≥ 3 abandonos en 7 días o ≥ 50 % de sus últimas 6 sesiones. Una desconexión (`disconnected`) nunca cuenta como abandono.
- **`control_abuse`:** el registro muestra `end_exam`, `next_part` o `go_to_part` hacia delante que se saltan más del 50 % del tiempo del examen, en ≥ 2 sesiones con compañeros distintos.
- **`noise`:** voz solapada > 40 % del tiempo en las Partes 3–4 según la medida del compañero, más un segundo reporte independiente. Por sí sola no sanciona.
- **Contenido ofensivo:** siempre revisión humana. Si hay grabación, quien revisa la escucha. Con `minor_safety` o amenazas, suspensión preventiva hasta la revisión, como mucho 72 h.

**Revisión manual:** una vista `moderation_queue` (solo `service_role`) ordenada por gravedad y veredicto, con el resumen de pruebas de cada caso: eventos, tiempos de voz, historial y otros reportes. Al principio basta con Supabase Studio. Más adelante, una pantalla interna.

**Grabación bajo revisión:** si hay un caso abierto sobre una sesión grabada, la grabación no se borra a los 30 días (se excluye de la limpieza y de la regla de ciclo de vida de R2) hasta cerrar el caso, con un máximo de 60 días. Solo la escucha quien revisa.

## 4. Escala de penalizaciones y recurso

Puntos por incidente confirmado: `silent` y `quit` 1; `noise`, `control_abuse` y `mocking` 2; contenido grave 6 (solo a mano). Los puntos **caducan a los 90 días**.

| Puntos activos | Medida | ¿Automática? |
|---|---|---|
| 1 | **Aviso** en la app, que explica qué se detectó y cuándo | Sí |
| 2–3 | **24 h sin emparejamiento en vivo**. La agenda con compañeros sigue disponible | Sí (solo con pruebas `corroborated`) |
| 4–5 | **7 días sin emparejamiento en vivo ni propuestas nuevas**. Las reuniones ya confirmadas se mantienen | Sí (solo con pruebas `corroborated`) |
| ≥ 6 o falta grave | **Bloqueo de la cuenta** | **Nunca**: siempre lo decide una persona |

- La suscripción no se pausa ni se devuelve por una suspensión corta. El bloqueo por incumplir los Términos necesita una cláusula en los Términos de uso **[REVISAR con abogado: derecho de consumo]**.
- **Recurso:** «Recurrir» desde el aviso, dentro de 14 días, con un texto libre. Lo revisa una persona en ≤ 72 h. Si se estima, se retiran los puntos y la medida, y se apunta en el caso. Mientras se resuelve el recurso de una suspensión automática, la suspensión sigue (son 24 h o 7 días), salvo que el caso sea `unverified`.
- Cada medida guarda su **motivo explicado** (DSA, art. 17: «exposición de motivos») y el reportante recibe el resultado («Hemos tomado medidas» o «No hemos encontrado pruebas suficientes»). **[REVISAR: obligaciones de la DSA para una plataforma pequeña.]**

## 5. Protección contra reportes falsos o por venganza

1. **Solo cuenta si estabas allí:** con contexto `lobby`, `exam` o `feedback`, `report_user` comprobará que quien reporta y el reportado son `user_a` y `user_b` de esa sesión. Hoy no lo comprueba. Un reporte por persona y sesión.
2. **Un reporte sin pruebas nunca sanciona.** Hacen falta pruebas objetivas o reportes independientes (personas distintas, sesiones distintas). Dos amigos que reportan a la misma persona en la misma sesión cuentan como uno.
3. **Reporte cruzado:** si A reporta a B después de que B reportara a A en la misma sesión, los dos reportes se marcan `cross_report` y van a revisión con las pruebas; ninguno sanciona solo.
4. **Credibilidad de quien reporta:** se calcula la proporción de sus reportes confirmados. Quien reporta en más del 30 % de sus sesiones o acumula reportes `contradicted` pierde peso y queda marcado para revisión.
5. **Reporte falso demostrado** (`contradicted` y confirmado a mano): 1 punto para quien lo hizo, con el motivo `false_report`.
6. Se mantiene el límite de 10 reportes al día. El aviso al reportado no dice si vino de un reporte o de la detección automática, para no avivar el conflicto, y se le sugiere bloquear.

## 6. Privacidad y RGPD

| Dato | Base legal | Conservación | Quién lo ve |
|---|---|---|---|
| `session_events`, `session_talk_stats` (números, sin audio) | Interés legítimo (art. 6.1.f): seguridad y equidad del servicio | **30 días**, como los chats y las grabaciones. Si hay un caso abierto, hasta cerrarlo + 6 meses | Ningún cliente. Quien revisa (`service_role`) |
| `user_reports`, `moderation_cases` | Interés legítimo; obligación de las tiendas (Apple 1.2) | 12 meses desde el cierre | Quien revisa. El reportante solo ve el estado |
| `user_strikes`, `user_restrictions` | Ejecución del contrato (Términos) | Activos 90 días; historial 12 meses | El afectado ve **los suyos** con su motivo |
| Grabación bajo revisión | Consentimiento de los dos (ya existe) + interés legítimo para la revisión | Hasta cerrar el caso, máx. 60 días | Solo quien revisa |

- **Decisiones automatizadas (art. 22):** las suspensiones automáticas son cortas y limitadas al emparejamiento, y siempre se pueden recurrir ante una persona (art. 22.3). El bloqueo nunca es automático.
- **Menores (14+):** con usuarios menores y un seguimiento de su comportamiento, conviene una evaluación de impacto (EIPD) breve **[REVISAR]**.
- **Política de privacidad:** añadir qué se mide (tiempo de voz por turno, sin grabar ni transcribir), para qué, cuánto tiempo y cómo recurrir.
- **Borrar la cuenta:** los reportes quedan con `reported_id = null`, como hoy. Para que nadie esquive un bloqueo con otra cuenta, se podría guardar durante 12 meses solo un hash del email de las cuentas **bloqueadas**. Es opcional **[REVISAR]**.

## 7. Impacto en Supabase

**Tablas nuevas** (RLS activada; ningún cliente escribe en ellas directamente):
- `session_events (id, session_id, user_id, kind, part, at, data jsonb)`.
- `session_talk_stats (session_id, segment_key, part, subject_id, measured_by 'self'|'partner', window_ms, speech_ms, overlap_ms, received_at)`, única por `(session_id, segment_key, subject_id, measured_by)`.
- `moderation_cases (id, reported_id, status, severity, opened_at, decided_at, decision, public_reason)`.
- `user_strikes (id, user_id, case_id, reason, points, created_at, expires_at, revoked_at)`.
- `user_restrictions (user_id, scope 'live'|'offers', until, case_id)`.
- `appeals (id, user_id, strike_id, text, status, created_at, decided_at)`.

**Cambios en lo que existe:**
- `user_reports`: motivos nuevos (`silent`, `quit`, `control_abuse`, `noise`, `mocking`) y columnas `verdict`, `case_id`, `evidence jsonb` (una foto de las pruebas al reportar) y `cross_report`.
- `report_user`: **misma firma**, para que la app actual siga funcionando. Añade la comprobación de pertenencia a la sesión, un reporte por sesión y la evaluación posterior.
- `private.ctl_apply` / control de sesión: además de `last_control`, añade una fila a `session_events`. El contrato Dart/SQL de los controles (`control-golden.json`) no cambia.
- `svc_match_enqueue` y crear oferta: comprueban `user_restrictions` y devuelven el error nuevo `restricted` con la fecha de fin.

**Funciones nuevas:** `private.evaluate_report(id)`, `private.apply_strike(...)`, `public.my_moderation_status()` (solo mis puntos, medidas y recursos), `public.appeal_create(strike, texto)`, y `admin_decide_case(...)` solo para `service_role`.

**Edge Functions:**
- `session-actions`: las acciones nuevas `talk_stats` (validada y una vez por segmento) y `self_mute`.
- `livekit-webhook`: además de `participant_joined/left`, registra `track_published/unpublished` en `session_events`.
- `cron-worker`: evalúa los reportes de las sesiones terminadas, hace caducar puntos y medidas, y purga eventos y estadísticas de más de 30 días sin caso abierto.

**App:** motivos nuevos en la hoja de reportar (contexto examen y feedback), medidor de voz por segmento a partir del nivel de audio de LiveKit (que ya llega como `ActiveSpeakers`), aviso y estado de la cuenta en Ajustes, formulario de recurso y mensaje de «emparejamiento suspendido hasta…».

**Tests:** una suite SQL nueva (`11_moderation.sql`): pertenencia, veredictos, caducidad, umbrales, reporte cruzado y que `report_user` acepte las mismas llamadas que hoy. También tests de Dart para el medidor y las pantallas.

## 8. Fases

1. **Recoger pruebas, sin sanciones:** registro de eventos, tiempos de voz, motivos nuevos y la comprobación de pertenencia. Durante 2–4 semanas se miran los datos reales para fijar los umbrales.
2. **Veredictos y avisos:** evaluación automática, cola de revisión, avisos y estado de la cuenta.
3. **Suspensiones y recursos:** restricciones en el emparejamiento y las propuestas, recursos, y la conservación de la grabación bajo revisión.
4. **(Opcional)** Medidor en el servidor con un agente de LiveKit.

## 9. Preguntas para Alfonso

1. ¿Te parecen bien los umbrales iniciales y la escala (aviso, 24 h, 7 días, bloqueo manual)?
Sí
2. ¿Quién revisa los casos? ¿Tú desde Supabase Studio al principio?
Sí 
3. ¿Quieres el hash del email de las cuentas bloqueadas para evitar que vuelvan con otra cuenta?
sí
4. ¿Empezamos por la fase 1 (solo recoger pruebas)?
sí