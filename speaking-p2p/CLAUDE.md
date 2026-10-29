# CLAUDE.md — Bootstrap del proyecto "Speaking P2P" (nombre provisional)

> Este archivo es tu contrato de trabajo. Léelo entero al empezar cada sesión.
> Trabaja de forma **autónoma**: no preguntes por inconsistencias. Decide según las reglas de la sección 1, registra la decisión y sigue.

---

## 0. Qué estamos construyendo

Una app móvil (iOS + Android) para **simular el examen oral (Speaking) de Cambridge por parejas, entre estudiantes (P2P)**. No hay examinador humano. Un "lector" (audio pregenerado) hace de examinador: lee enunciados, asigna turnos y controla los tiempos. Al final los dos estudiantes se dan feedback mutuamente.

- **Niveles del MVP:** B1 Preliminary, B2 First, C1 Advanced.
- **Fuera del MVP:** A1, A2, C2, Trinity e IELTS (tendrán otro formato en el futuro). Transcripción de grabaciones. Feedback estructurado con rúbrica. Sistema de reputación (solo se **registran** las ausencias, sin lógica todavía).

---

## 1. Reglas de autonomía

1. **Fuente de verdad, en este orden:**
   1. este archivo;
   2. `docs/DECISIONS.md`;
   3. el vault de Obsidian en `docs/vault/`.
2. **El vault es tu guía técnica.** Contiene un proyecto anterior del mismo autor con llamadas (incluido el segundo plano), chats, perfiles y usuarios, ya resueltos con Supabase, Cloudflare, LiveKit y AdMob.
   - **Antes de implementar** cualquier módulo de esos ámbitos, busca en el vault cómo se hizo y **reutiliza patrones, estructura, librerías y framework**.
   - Si el vault contradice este archivo en **producto**, gana este archivo.
   - Si lo contradice en **técnica** (librerías, configuración), gana el vault.
3. **Framework móvil:** el mismo que el del proyecto del vault. Si el vault no lo deja claro, usa React Native + Expo (dev client) + TypeScript.
4. **Ante una ambigüedad no resuelta aquí:**
   - elige la opción más simple que no bloquee futuras ampliaciones;
   - apúntala en `docs/DECISIONS.md` (fecha, contexto, decisión, alternativa descartada);
   - continúa sin preguntar.
5. **Progreso:** mantén `docs/PROGRESS.md` (hitos, estado, siguiente paso). Haz un commit por cada unidad funcional que compile y pase sus tests. No dejes la rama principal rota.
6. **Presupuesto:** los créditos acaban el **4 de noviembre de 2026**.
   - Prioriza los hitos en el orden de la sección 12.
   - No generes contenido masivo antes de que el motor del examen funcione.
   - No reescribas lo que ya funciona.
7. **Secretos:** nunca en el repo. Usa `.env.example` con las claves documentadas. Si falta una credencial, crea un mock o stub, apúntalo en `PROGRESS.md` y sigue con otra cosa.
8. **Idioma:**
   - código, identificadores y commits en inglés;
   - documentación interna en español;
   - textos de la UI siempre por i18n (ES/EN), nunca hardcodeados.

---

## 2. Stack

| Ámbito | Tecnología | Notas |
|---|---|---|
| Backend / BD / Auth / Realtime | **Supabase** (Postgres, RLS, Edge Functions, Realtime, pg_cron) | Ver vault |
| Multimedia | **Cloudflare R2** (+ CDN) | Avatares, audios del lector, fotos de exámenes, grabaciones. Subidas con URL firmada desde una Edge Function |
| Llamadas | **LiveKit** (solo audio) | Ver vault, incluido el segundo plano. **No hay vídeo** |
| Anuncios | **AdMob** | Solo "App Open Ad" |
| Pagos | **RevenueCat** sobre App Store / Google Play | Salvo que el vault use otra cosa. Webhook → Supabase |
| Errores | **Sentry** | App y Edge Functions |
| Producto / retención | **PostHog** | Eventos en la sección 11 |
| Push | El sistema del vault (si no hay: Expo Notifications / FCM + APNs) | |

---

## 3. Usuarios, autenticación y acceso

### Autenticación
- **Solo Google Sign-In** a través de Supabase Auth.
- Edad mínima: **14 años**. Se pide la fecha de nacimiento y se bloquea el registro si es menor de 14.
- Teléfono: se pide y se guarda **sin verificar**.

### Datos públicos y privados
- **Públicos:** `username` (único), avatar (R2), idiomas que habla (multiselección).
- **Privados:** fecha de nacimiento/edad, teléfono, email.
  - Ningún otro usuario puede leerlos.
  - Usa una vista `public_profiles` y una RLS estricta sobre `profiles_private`.

### Onboarding
Los pasos son, en orden:
1. Login con Google.
2. Username.
3. Avatar (opcional).
4. Idiomas.
5. Fecha de nacimiento.
6. Teléfono.
7. Nivel objetivo (B1/B2/C1, modificable después en el perfil).
8. Aceptación de los Términos de uso y la Política de privacidad. **Guarda la versión aceptada y la fecha.**

### Modelo de acceso (no existe plan gratuito)
- Cada usuario nuevo tiene **1 test de prueba**.
- Ese test **se consume al empezar la Parte 1** (no en el lobby).
- Después solo puede usar la app quien tenga **suscripción activa de 8 €/mes**.
- Sin suscripción ni test disponible, todo el contenido funcional queda tras un **paywall**: matchmaking, agenda y ofertas.
  - Sí puede acceder a perfil, ajustes y paywall.
- **Para entrar en el matchmaking, crear o aceptar una reunión**, el usuario debe ser elegible (suscripción activa o test de prueba sin usar).
  - Compruébalo en el servidor, no solo en el cliente.
- **Anuncios:** **un App Open Ad por arranque en frío**, para todos los usuarios, también los de prueba. Nunca durante el lobby, el examen ni el feedback.

### Borrado de cuenta
Debe existir **eliminar cuenta** en Ajustes (lo exigen las tiendas). Al eliminar:
- se borran los datos personales;
- los mensajes de chat quedan anonimizados.

---

## 4. Estructura de los exámenes (simulación cercana, contenido propio)

**El contenido es original**, inspirado en el formato oficial. **Nunca copies material oficial.**

Las duraciones son las aproximadas del examen real; úsalas como valores por defecto en el JSON.

| Parte | B1 Preliminary | B2 First | C1 Advanced |
|---|---|---|---|
| 1. Interview | ~2–3 min. Preguntas personales alternas a A y B (respuestas cortas, ~20–30 s) | ~2 min. Preguntas alternas, ~20–30 s | ~2 min. Preguntas alternas, ~20–30 s |
| 2. Long turn (imágenes) | Cada uno **describe 1 foto** ~1 min | Cada uno **compara 2 fotos** + pregunta impresa, **1 min**. El otro responde a una pregunta breve, **~30 s**. Después se invierte | Cada uno **elige 2 de 3 fotos**, 1 min. El otro responde, ~30 s. Se invierte |
| 3. Collaborative (burbuja) | Situación + **5 opciones** en un diagrama. Discusión conjunta **~2–3 min** | Diagrama con **pregunta central + 5 prompts**: **2 min** de discusión + **1 min** de decisión | Igual que B2: **2 min** + **1 min** de decisión |
| 4. Discussion | Conversación general sobre el tema de la Parte 3, **~3 min** | Preguntas abiertas sobre el tema de la Parte 3, **~4 min** | Igual, **~5 min** |

### Reglas de micrófono (las aplica el servidor, no solo la UI)
- **Partes 1 y 2:** mientras el lector habla, **ambos micros silenciados**. Al asignar el turno, se enciende el micro del destinatario y se apaga el del otro.
  - La UI ilumina la tarjeta del usuario activo y atenúa la del otro. **Ambos ven lo mismo.**
- **Partes 3 y 4:** ambos micros silenciados **solo mientras el lector lee el enunciado o la pregunta**. Después, **los dos micros abiertos**.
  - En la Parte 4 el lector puede dirigir una pregunta a A, a B o a ambos, pero el micro sigue abierto para los dos.
- **Aplicación técnica:** el servidor actualiza los permisos `canPublish` del participante (LiveKit server API), igual que en el vault si existe un patrón. El cliente refleja el estado.

### Asignación de roles
- **A** y **B** se asignan al azar al crear la sesión.
- A abre la Parte 1 y la Parte 2; dentro de cada parte se alternan los turnos.

---

## 5. Contenido estático de exámenes

### Dónde vive cada cosa
- **En el bundle de la app**, como JSON versionado en `content/exams/{level}/{examId}.json`, más un `content/index.json`. **No va en la base de datos.**
- **Los binarios no van en el bundle** (para no inflar la app):
  - audios del lector: **TTS de calidad pregenerado**;
  - fotos de la Parte 2.
- Los binarios se suben a **R2** con rutas deterministas:
  - `audio/{level}/{examId}/{stepId}.mp3`
  - `img/{level}/{examId}/{assetId}.webp`
- **Precarga:** la app descarga los assets del examen **durante el lobby**. El examen no empieza hasta que **ambos clientes** confirman la precarga, o pasados 5 minutos.

### Esquema del examen
Créalo con Zod y un validador en CI.

```ts
type Exam = {
  id: string; level: 'B1'|'B2'|'C1'; version: number; topic: string;
  parts: Part[];               // 4 partes
};
type Part = { index: 1|2|3|4; title: string; steps: Step[] };
type Step =
  | { id: string; kind: 'narration'; text: string; audio: string }            // ambos mudos
  | { id: string; kind: 'turn'; target: 'A'|'B'; text: string; audio: string;
      durationSec: number; assets?: string[] }                                // solo target habla (P1–P2)
  | { id: string; kind: 'open'; target: 'A'|'B'|'both'; text: string; audio: string;
      durationSec: number; diagram?: string }                                 // ambos hablan (P3–P4)
```

### Diagramas de burbuja (Parte 3)
- **No son imágenes.** Son JSON (`content/diagrams/{id}.json`) que la app **dibuja de forma nativa**, con la pregunta central y los prompts en burbujas. Deben soportar el tema claro y el oscuro.
- Esquema: `{ id, centralQuestion, prompts: string[5], decisionQuestion }`.
- Deja preparado (sin implementar en el MVP) un "editor manual" futuro que escriba este mismo JSON.

### Generación de contenido
Hazla tú, con scripts en `scripts/content/`:
1. Genera los exámenes, originales y ajustados a la dificultad del nivel.
2. Genera el TTS de cada step con una voz neutra de "examinador".
3. Genera o selecciona las fotos (IA o libres de derechos; **apunta la licencia** en `content/LICENSES.md`).
4. Sube todo a R2.

**Volumen del MVP:** **5 exámenes por nivel** (15 en total). Amplía solo cuando los hitos 1–6 estén terminados.

### Rotación de exámenes
- Al crear una sesión, el servidor elige un examen del nivel que **ninguno de los dos haya hecho**. Si no queda ninguno, elige el más antiguo para ambos.
- El historial se guarda en la base de datos (`exam_history`).

---

## 6. Sesión de examen (máquina de estados controlada por el servidor)

### Estados
`lobby → part1 → part2 → part3 → part4 → feedback → ended` (o `aborted`).

- **El servidor es la autoridad del estado.** Supabase guarda la sesión y una Edge Function avanza el estado. Los cambios se difunden por Realtime o por data messages de LiveKit.
- **Cada step lleva `startedAt` del servidor.** Los clientes calculan el tiempo restante con esa referencia: nada de cronómetros locales independientes.
- El audio del lector lo reproduce **cada cliente en local**, sincronizado con el `startedAt` del step.

### Lobby (máx. 5 min)
- Llamada libre para conocerse.
- Botón **"Listo"**. Cuando los dos lo pulsan, empieza la Parte 1. A los 5 minutos empieza automáticamente.
- **Grabación:** cada usuario activa un interruptor. **Se graba solo si los dos lo activan.**

### Durante el examen
- **Cronómetro** visible arriba con el tiempo restante del step, con un botón para ocultarlo o mostrarlo.
- **Botón "Ver texto"** (activar/desactivar) que muestra lo que dice el lector en el step actual.
- **Botón Abandonar** disponible para **cualquiera de los dos**:
  1. abre un diálogo "¿Seguro que quieres salir?";
  2. el botón de confirmar queda **bloqueado durante 5 s con una cuenta atrás**;
  3. si confirma, la sesión pasa a `aborted`;
  4. el otro usuario ve "Tu compañero ha salido" y vuelve al inicio.
- **El test de prueba sigue consumido** si la sesión ya había llegado a la Parte 1.

### Feedback y cierre
- **Feedback:** 5 minutos de llamada libre con los micros abiertos y cuenta atrás. Al terminar, la sesión pasa a `ended` y se cuelga.
- **Desconexión:** se dan 60 s de gracia para reconectar; después, `aborted`. La llamada en segundo plano debe funcionar como en el vault.

### Grabación (opcional)
- LiveKit Egress **solo de audio**, guardado en R2.
- Ambos participantes la pueden escuchar durante **30 días** (URL firmada). Después se borra (lifecycle rule de R2 y cron de limpieza en la BD).

---

## 7. Matchmaking en vivo

1. Pantalla con una **animación de búsqueda minimalista y con movimiento** (por ejemplo, ondas o pulsos suaves, a 60 fps).
2. Cola por **nivel exacto** (sin niveles adyacentes en el modo en vivo). El emparejamiento es atómico en el servidor (FIFO).
3. Al encontrar pareja, se crea la sesión (sección 6) y se entra al lobby.
4. **Ventana a los 15 s:** si pasan 15 s sin match **y** el usuario **no tiene ninguna reunión creada ni aceptada abierta**, aparece una ventana arriba: "Parece que no hay nadie buscando hacer un examen, ¿quieres agendar una reunión con alguien?".
   - **Sí:** lleva a Agenda → Crear reunión.
   - **No:** sigue buscando.
5. Antes de entrar en la cola se comprueba la elegibilidad (sección 3).

---

## 8. Agenda (reuniones + chat)

La pestaña **Agenda** tiene tres partes:
- **Chats:** la lista de conversaciones.
- **Reuniones:** el tablón de ofertas abiertas de otros usuarios.
- **Mi agenda:** las reuniones confirmadas, en lista o calendario.

Arriba, el botón **"Crear reunión"**.

### Crear una oferta
- Se elige una **franja horaria** (inicio y fin, con el mismo día o varios permitidos dentro de los próximos 7 días) y un **nivel** (B1/B2/C1).
- Máximo **2 ofertas activas** por usuario. Aceptar ofertas de otros no tiene límite.

### Tablón "Reuniones"
- Muestra las ofertas de otros usuarios, filtradas por defecto por mi nivel.
- **Aquí sí se permite ver niveles adyacentes** (B1↔B2, B2↔C1) con un filtro.
- No se muestran mis propias ofertas ni las ofertas ya vencidas.

### Aceptar una oferta
1. B toca la oferta y **elige una hora exacta dentro de la franja**.
2. Se crea un **chat A-B** con la **tarjeta de reunión fijada arriba**, que muestra fecha, hora, nivel y el estado de confirmación de cada uno.
3. **Varios usuarios pueden aceptar la misma oferta.** Cada aceptación crea su propio chat, y la oferta sigue abierta hasta que A confirma con alguien.

### Tarjeta de reunión en el chat
Tiene tres acciones: **Modificar** (hora o nivel), **Cancelar** y **Confirmar**.
- La reunión queda confirmada cuando confirman **los dos**.
- Cada uno ve un **tick** cuando el otro ha confirmado.
- **Modificar** reinicia las confirmaciones de ambos.
- **Al confirmarse:**
  - se crea la entrada en "Mi agenda" de los dos;
  - la oferta se retira del tablón;
  - los demás chats de esa oferta reciben un mensaje de sistema ("Esta reunión ya no está disponible") y su tarjeta pasa a `closed`. El chat sigue existiendo.
- **No se permiten solapes.** Se rechaza confirmar si choca con otra reunión confirmada del mismo usuario. Una reunión ocupa un bloque de 30 min.

### Chat
- Mensajes de texto en tiempo real (patrón del vault) con mensajes de sistema para los cambios de la tarjeta.
- En la cabecera, nombre y avatar públicos del otro usuario.

### Inicio de una reunión agendada
- Push a los dos **10 min antes**.
- Desde 5 min antes, en la tarjeta y en Mi agenda aparece el botón **"Entrar a la sala"**, que lleva al lobby de la sesión.
- **10 min de cortesía** tras la hora:
  - si alguien no entra, la reunión pasa a `no_show` y se registra la ausencia en `attendance` (para la reputación futura);
  - el que sí entró recibe un aviso.

---

## 9. Perfil y Ajustes

**Perfil:** se pueden editar username, avatar, idiomas y nivel objetivo.

**Ajustes:**
- tema claro/oscuro (por defecto el del sistema, con override persistente);
- idioma de la UI ES/EN;
- **información de la suscripción** (estado y fecha del próximo pago, vía RevenueCat) con acceso a gestionarla en la tienda;
- Términos y Privacidad;
- cerrar sesión;
- eliminar cuenta.

---

## 10. Modelo de datos (Supabase, orientativo)

Adáptalo a las convenciones del vault. **Activa RLS en todas las tablas.**

- `profiles` — id (= auth.uid), username, avatar_url, languages[], target_level, created_at
- `profiles_private` — id, birth_date, phone, email, terms_version, terms_accepted_at
- `entitlements` — user_id, trial_used_at, subscription_status, current_period_end (lo actualiza el webhook de RevenueCat)
- `match_queue` — user_id, level, enqueued_at
- `exam_sessions` — id, level, exam_id, user_a, user_b, state, step_index, step_started_at, recording_consent_a/b, recording_url, origin ('live'|'meeting'), meeting_id, created_at, ended_at
- `exam_history` — user_id, exam_id, session_id, completed
- `meeting_offers` — id, creator_id, level, window_start, window_end, status ('open'|'filled'|'cancelled'|'expired')
- `meetings` — id, offer_id, creator_id, acceptor_id, level, scheduled_at, creator_confirmed, acceptor_confirmed, status ('pending'|'confirmed'|'cancelled'|'closed'|'done'|'no_show')
- `chats`, `chat_messages` — mensajes de usuario y de sistema, ligados a meeting_id
- `attendance` — meeting_id, user_id, attended bool
- `push_tokens`

**Crons (pg_cron):**
- expirar ofertas;
- enviar los avisos de 10 min;
- marcar los `no_show`;
- limpiar las grabaciones de más de 30 días.

---

## 11. Analítica y errores

**Sentry:** en la app y en las Edge Functions, con source maps.

**Eventos mínimos de PostHog:**
- `signup_completed`
- `paywall_viewed`, `subscription_started`, `subscription_cancelled`
- `matchmaking_started`, `matchmaking_matched` (tiempo de espera), `matchmaking_prompt_shown`, `matchmaking_prompt_accepted`
- `exam_lobby_entered`, `exam_part_started` (parte), `exam_completed`, `exam_aborted` (parte, quién abandonó)
- `text_toggle_used`, `timer_toggle_used`
- `meeting_offer_created`, `meeting_accepted`, `meeting_confirmed`, `meeting_no_show`
- `app_open_ad_shown`

Prepara cohortes de retención D1/D7/D30.

---

## 12. Hitos (en este orden)

0. **Setup.**
   - Lee `docs/vault/` y resume en `docs/VAULT_NOTES.md` los patrones que vas a reutilizar.
   - Crea el scaffold, CI, linters, i18n y tema claro/oscuro.
1. **Auth y onboarding.** Login con Google, perfil público/privado, avatar en R2.
2. **Motor del examen offline.**
   - Esquema de contenido, 1 examen por nivel y diagramas de burbuja.
   - Reproductor del lector, cronómetro y botón "Ver texto".
   - Un **modo de desarrollo con compañero simulado** para probar sin dos dispositivos.
3. **Llamada y sesión sincronizada.**
   - LiveKit solo audio.
   - Estados controlados por el servidor y permisos de micro.
   - Lobby, feedback, abandono y reconexión, con soporte de segundo plano.
4. **Matchmaking en vivo**, con la ventana de los 15 s.
5. **Agenda.** Ofertas, tablón, chats, tarjeta de reunión, confirmaciones, push y no-show.
6. **Acceso y monetización.** Test de prueba, RevenueCat, paywall, App Open Ad y Ajustes de suscripción.
7. **Contenido completo** (5 por nivel), grabación opcional, analítica completa, Términos y Privacidad, y eliminar cuenta.
8. **Pulido.** Animaciones, accesibilidad y pruebas end-to-end de los flujos críticos.

**Cada hito se cierra cuando:**
- compila;
- pasan los tests de lógica (máquina de estados, reglas de agenda, elegibilidad);
- `PROGRESS.md` está actualizado;
- se ha hecho commit.

---

## 13. Decisiones tomadas en la fase de producto (no reabrir)

- **Formato:** solo llamadas de audio, sin vídeo. No hay moderación más allá de los Términos y la opción de abandonar.
- **Contenido:** propio, no oficial; basta con una simulación cercana.
- **Monetización:** sin plan gratuito. 1 test de prueba, luego 8 €/mes. Un App Open Ad por arranque, para todos.
- **Acceso:** solo Google. Teléfono sin verificar. Edad mínima 14.
- **Lector:** TTS pregenerado en R2, con texto mostrable u ocultable.
- **Grabación:** opcional, con consentimiento de los dos y 30 días de retención. Sin transcripción en el MVP.
- **Emparejamiento:** en vivo, solo nivel exacto. En la agenda, filtro de niveles adyacentes.
- **Agenda:** B elige la hora dentro de la franja. Oferta abierta hasta confirmar. Aviso 10 min antes y 10 min de cortesía.
- **Test de prueba:** se consume al empezar la Parte 1.
- **Pendiente para más adelante:** reputación (solo se registran ausencias) y feedback estructurado con rúbrica.
