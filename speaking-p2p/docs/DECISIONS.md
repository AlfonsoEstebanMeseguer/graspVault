# Decisiones

> Formato: fecha · contexto · decisión · alternativa descartada. Ordenadas por número.
> Fuente de verdad nº 2 tras CLAUDE.md.

### D-001 · 2026-10-15 · Dónde vive el proyecto
- **Contexto:** CLAUDE.md espera el vault en `docs/vault/`, pero la sesión se abrió sobre el repo `graspVault`, que *es* el vault.
- **Decisión:** el proyecto vive en `speaking-p2p/` dentro de este repo; el vault queda intacto en la raíz (no se mueve para no romper Obsidian). El CI va en `.github/workflows/speaking-p2p.yml` filtrado por ruta.
- **Descartada:** mover el vault a `docs/vault/` (rompe la estructura del usuario). **Recomendado a futuro:** repo propio (`git subtree split --prefix speaking-p2p`), pendiente de confirmación.

### D-002 · Framework móvil: Flutter
- El vault usa Flutter + Riverpod + go_router con decisiones y trampas documentadas. CLAUDE.md §1.3 manda usar el del vault. React Native descartado.

### D-003 · La sesión se dirige con una línea temporal precomputada
- **Contexto:** "el servidor es la autoridad del estado" y "cada step lleva startedAt del servidor", pero los steps duran 20–60 s y pg_cron no da precisión de segundos.
- **Decisión:** al empezar la Parte 1 el servidor copia en `exam_sessions.schedule` la línea temporal del examen (segmentos *lector* y *habla* con su política de micro). El estado es función de `now − exam_started_at`. `svc_session_tick` es idempotente: lo llaman ambos clientes en cada frontera y un cron cada 10 s como red de seguridad; si el segmento cambió, la Edge Function aplica `canPublish` en LiveKit y marca `applied_segment` (compare-and-set). 3 s de margen antes de la Parte 1.
- **Descartada:** una función que avance paso a paso con timers (no existe un timer fiable en Edge Functions; un fallo deja la sesión colgada).

### D-004 · `audioMs` obligatorio en cada step (amplía el esquema de CLAUDE.md §5)
- Sin la duración del audio del lector el servidor no sabe cuándo abrir los micros (los `narration` ni siquiera tenían duración). `scripts/content/fill-derived.ts` la estima por palabras; el script de TTS escribirá la real.

### D-005 · Un "golden" compartido entre TypeScript y Dart
- La línea temporal existe dos veces (servidor y app). `content/fixtures/timeline-golden.json` la fija: los dos test suites lo comparan. Cambiar una sin la otra pone el CI en rojo.

### D-006 · El email no se duplica en `profiles_private`
- Ya está en `auth.users` (minimización, Art. 5.1.c). La app lo muestra desde la sesión.

### D-007 · Lápida anti-abuso del test de prueba
- `trial_claims(sha256(email))` sin FK: borrar la cuenta y volver a entrar con la misma cuenta de Google no regala otro test. Cuentas de Google nuevas sí (riesgo aceptado, ver REVIEW).

### D-008 · El reloj del lobby arranca cuando los dos están dentro
- Si arrancara al crear la sesión, en una reunión agendada (sala abierta desde −5 min) el examen empezaría con uno solo. En vivo, si alguien no entra en 90 s, la sesión se aborta como `no_show` (fantasmas de la cola).

### D-009 · Latido de la cola en vivo
- El cliente re-llama a `enqueue` cada ~10 s; quien no late en 25 s no se empareja y a los 60 s se borra. Evita emparejar con alguien que cerró la app.

### D-010 · Reglas de negocio en SQL (`svc_*`), ejecutables solo por `service_role`
- Toman el usuario explícito (la Edge Function ya verificó el JWT) y `p_now` para poder mover el reloj en tests. Errores con código estable en el mensaje (`not_eligible`, `overlap`…) → la app los traduce por clave.

### D-011 · `CHECK` en línea, nunca llamando a funciones de `private`
- Encontrado por la suite: un `CHECK` corre con los privilegios de quien escribe y el cliente no tiene `EXECUTE` en `private` → todo `UPDATE` de perfil fallaba.

### D-012 · Versión de contenido
- El catálogo del servidor (`exam_catalog`) lleva `content_version`; el cliente envía la suya y el servidor nunca elige un examen que esa build no tenga. Si aun así falta (reunión con una app vieja), la sesión se aborta con `content_missing`.

### D-013 · Buckets de R2
- `content` (audio y fotos de examen): **público** tras dominio propio con CDN; no es dato personal.
- `media` (avatares): privado, URL firmada 300 s.
- `recordings`: privado, **bucket y token propios** (las credenciales se entregan a LiveKit Egress), regla de ciclo de vida 30 días + cron de limpieza.

### D-014 · Tarjeta de reunión
- Solo se **modifica** una reunión `pending`; una confirmada se **cancela**. Cancelar una confirmada no reabre la oferta (las otras aceptaciones ya recibieron "no disponible").
- Horas en múltiplos de 5 min; la franja mínima es 30 min y la reunión tiene que caber entera.

### D-015 · Borrado de cuenta con solo Google
- Reautenticación = inicio de sesión con Google de hace menos de 5 min (`iat` del JWT) + frase `ELIMINAR`/`DELETE` comprobada en el servidor. Borra también las grabaciones donde aparece su voz.

### D-016 · Push
- FCM HTTP v1 directo (Android e iOS vía APNs en Firebase), textos localizados en el dispositivo con `loc-key`. Cola `notification_outbox` con reintentos.

### D-017 · SDKs nativos en su hito
- LiveKit, RevenueCat, AdMob, Sentry y PostHog se añaden al pubspec en el hito que los usa: AdMob, por ejemplo, tumba la app al arrancar sin su `APPLICATION_ID` en el manifiesto.

### D-018 · Política de micro fuera de las partes
- Lobby y feedback: los dos abiertos. Lector: los dos cerrados. `turn`: solo el destinatario. `open`: los dos.

### D-019 · Modo práctica sin conexión
- `/practice/:level?at=<ms>&role=B` arranca el examen local con compañero simulado y permite saltar a cualquier punto (necesario para probar sin dos dispositivos y sin esperar 15 min).

### D-020 · 2026-10-15 · "Todos han pagado" mientras RevenueCat está aplazado
- **Contexto:** Alfonso aplaza RevenueCat y asume 8 € de entrada.
- **Decisión:** `app_config.assume_paid = true` → un trigger da a cada usuario NUEVO suscripción activa hasta 2100. La lógica de test de prueba/paywall sigue intacta y testeada (la suite apaga el interruptor). Apagarlo no toca a los usuarios ya creados.
- **Descartada:** quitar la comprobación de elegibilidad (habría que volver a escribirla y probarla).

### D-021 · El token del cron se verifica contra Vault
- `cron-worker` llama a `svc_verify_internal_token`, que compara hashes con el secreto `internal_cron_token` de Vault. Desaparece `INTERNAL_CRON_TOKEN_SHA256`: ningún secreto se copia a mano entre sistemas.

### D-022 · Login por email y contraseña (provisional)
- Google Sign-In aplazado hasta tener los clientes OAuth. Supabase Auth email+password; el resto del sistema no depende del proveedor. La reautenticación del borrado sigue siendo "sesión de menos de 5 min".

### D-023 · R2: un endpoint por bucket con el bucket en la ruta
- Nombres del proyecto: `R2_ENDPOINT_SPEAKING_{MEDIA,CONTENT,RECORDINGS}` + `R2_{MEDIA,RECORDINGS}_{ACCESS,SECRET}_KEY`. El bucket se lee de la ruta (no hay variable `*_BUCKET` que pueda contradecirlo) y todos los valores se recortan al leerlos (un salto de línea pegado rompía la firma: pasó).
- Sin dominio CDN: el contenido del examen también se sirve con URL firmada (`media-view-url`, `kind: content`, 2 h).

### D-024 · Migraciones aplicadas con el MCP y canonizadas
- Cada fichero local se renombra al `version` que registra Supabase (vault ADR 0034). La regla de negocio se partió en 4 migraciones para que cada `apply` fuera manejable. El catálogo se cargó descargando `seed/exam_catalog.sql` de la rama y comprobando su md5 contra el local antes de ejecutarlo.

### D-025 · Edge Functions desplegadas como un único fichero
- `scripts/deploy/bundle-functions.mjs` (esbuild) inlina `_shared` y deja `npm:`/`jsr:` como imports. Comprobación tras desplegar: sin usuario, cada función devuelve su propio 401 (prueba que el bundle carga).

### D-026 · 2026-10-15 · Migraciones con `DELETE`: script único para el SQL Editor
- **Contexto:** el conector de Supabase pide confirmación para cualquier sentencia con `DELETE` y el diálogo caduca a los 60 s (pasó cuatro veces, también con la aprobación dada en el chat).
- **Decisión:** `apps/backend/supabase/manual/apply_pending_2026-10-15.sql` junta las tres migraciones pendientes en una transacción y las registra en `supabase_migrations.schema_migrations` con el mismo `version` que el fichero local. Se niega a correr dos veces. Probado en Postgres 16 local (aplica, registra y la segunda ejecución falla limpia).
- **Descartada:** reescribir las funciones para esquivar la palabra `DELETE` (sería engañar al control de seguridad).

### D-027 · Reautenticación del borrado con email
- Con login por email (D-022), "sesión de menos de 5 min" = la app vuelve a pedir la contraseña (`signInWithPassword`) justo antes de llamar a `account-delete`. El servidor no cambia: comprueba `iat` y la frase.

### D-028 · Horas de la agenda en la zona del móvil, rejilla en UTC
- Las franjas y huecos se calculan en UTC (rejilla de 30 min) y se muestran en hora local. Un test con `TZ=Europe/Madrid` encontró que el redondeo trataba una hora local como UTC; corregido.

### D-029 · 2026-10-22 · Botón de debug "Crear sala ahora"
- **Contexto:** probar la llamada exigía agendar con 5 min de antelación y esperar.
- **Decisión:** `meeting-actions {enter_now}` → `svc_meeting_enter_now`. Crea una sesión `live` (sin `meeting_id`, para no marcar la reunión como `done`/`no_show`) entre los dos miembros de una reunión pendiente o confirmada; quien lo pulse en los 5 min siguientes entra en el mismo lobby. Solo funciona con `app_config.dev_instant_rooms = true` y el botón solo se dibuja con `kDebugMode`. **Apagar el interruptor antes de publicar.**
- **Descartada:** relajar la ventana de −5/+10 min de `svc_meeting_enter` (cambiaría la regla real).

### D-030 · 2026-10-22 · La sesión se lee por columnas, no con `.stream()`
- **Contexto:** `.stream()` de supabase_flutter hace `select *`; `exam_sessions` solo concede columnas concretas (la `recording_key` no sale del backend) y Postgres respondía `permission denied` → "No se ha podido entrar en la sala" aunque el audio ya conectaba.
- **Decisión:** `watch()` relee la fila con columnas explícitas al suscribirse y en cada `UPDATE` de Realtime (el payload solo se usa como aviso). Patrón del vault ADR 0038.
- **Descartada:** `grant select` de la tabla entera (expondría la clave de la grabación).

### D-031 · 2026-10-22 · Silenciarse a uno mismo y "saltar" de debug
- **Silenciar:** el icono del micro era solo un indicador. Ahora `VoiceService.setSelfMuted` cierra **mi** micro; el micro queda abierto solo si el servidor lo permite (`canPublish`) **y** no me he silenciado. No existe silenciar al otro (vault ADR 0033).
- **Saltar (debug):** `session-actions {skip}` → `svc_session_debug_skip`. En el lobby adelanta `lobby_deadline` a ahora; en el examen retrasa `exam_started_at` (y `feedback_ends_at`) lo que falte del segmento actual: siguiente segmento, feedback o fin. Los clientes rehacen el `ExamEngine` cuando cambia `exam_started_at`. Solo con `app_config.dev_session_skip = true` y botones con `kDebugMode`. **Apagar antes de publicar** (junto con `dev_instant_rooms`).
- **Descartada:** un `step_index` forzado (rompería la regla "el estado sale de now − exam_started_at").

### D-032 · 2026-10-22 · Rediseño "premium y calmado" + contador en directo
- Briefing de Alfonso (cuestionario): minimal moderno tipo Linear, verde esmeralda/lima, fondo aurora, animación media, sin mascota, Inter, inicio bento, barra flotante en píldora, sin gamificación, oscuro casi negro, tono cercano. Primero propuesta (paleta + Inicio), luego el resto.
- Tokens nuevos por rol: `accent/onAccent`, `aurora`, `glow`, `glass`. El test de contraste los cubre (AA en claro y oscuro). Inter va en el bundle (OFL), sin descarga en tiempo de ejecución.
- `live_activity()` (security definer, solo `authenticated`): devuelve **solo recuentos** (buscando por nivel con latido < 25 s, exámenes en curso). Quién busca nunca sale de la base de datos.
- **Revertido el 2026-10-23:** Alfonso prefiere el frontend inicial. Se restauraron tema, paleta, navegación e Inicio; se quitaron Inter y las claves i18n del rediseño. `live_activity()` sigue en la BD (inofensiva, sin uso). Copia del rediseño fuera del repo por si se retoma.

### D-033 · 2026-10-23 · Voz del examinador: Kokoro en local, 4 voces
- **Contexto:** sin presupuesto para TTS de pago; se quieren varias voces.
- **Decisión:** Kokoro-82M (Apache-2.0) vía kokoro-onnx, generado en local (`scripts/content/tts/generate.py`): 4 voces británicas (`bf_emma`, `bm_george`, `bf_isabella`, `bm_lewis`), MP3 mono 64 kbps (~11 MB para los 3 exámenes × 4 voces). `audioMs` pasa a ser la duración **real** (la voz más larga + 250 ms), así la línea temporal del servidor nunca corta al lector; tras generar: validate → sync-catalog → sync-app y re-seed de `exam_catalog`.
- Ruta en R2: `audio/{voz}/{nivel}/{examen}/{paso}.mp3`; el JSON conserva la ruta sin voz y la app la inserta. `media-view-url` acepta el segmento de voz.
- La voz de una sesión sale de un hash estable del `sessionId` (ambos móviles la misma; cambia entre sesiones). En práctica, aleatoria. El audio se descarga en el lobby (lo que marca "Material descargado") y se reproduce desde disco; si falla, el lector queda mudo y el texto sigue en pantalla.
- **Descartadas:** TTS del sistema (flutter_tts: calidad y voces distintas en cada móvil, sin sincronía exacta); Google Cloud TTS (requiere cuenta de facturación); Edge TTS (gratuito pero no oficial).

### D-034 · 2026-10-23 · Foto de perfil
- **Flujo (vault ADR 0010/0012/0013/0014):** hoja modal sobre Perfil (galería, cámara, quitar) → recorte propio en círculo (InteractiveViewer, sin `image_cropper`) → 512 px → WebP, o JPEG si el móvil no codifica WebP; el mime se declara **según los bytes producidos** → `avatar-upload-url` firma el PUT → subida directa a R2 `speaking-media` → `avatar-confirm` comprueba los magic bytes y escribe `profiles.avatar_key`. El trigger encola la foto anterior para borrarla (`storage_gc`).
- `avatar-confirm {remove: true}` deja el perfil sin foto (vuelve la inicial).
- La app cachea los **bytes** por `(userId, avatar_key)` durante la ejecución: la clave es inmutable (uuid nuevo por foto), así que nunca enseña una foto vieja y no depende de que la URL firmada (300 s) siga viva. Si falla, se ve la inicial.
- Se ve en Perfil, chats, cabecera del chat, tablón, aceptar oferta, lobby y tarjetas del examen.
- **Sin avatares prediseñados** (los tenía Grasp): CLAUDE.md solo pide avatar en R2 y opcional.

### D-035 · 2026-10-23 · Banco de 150 exámenes y fotos locales
- **Contexto:** se piden 50 exámenes por nivel (B1/B2/C1), originales y con el formato Cambridge. CLAUDE.md fijaba 5 por nivel para el MVP; el usuario lo amplía expresamente.
- **Autoría:** `scripts/content/authoring/*.txt` (formato terso, 1 bloque por examen) → `scripts/content/author.ts` genera `content/exams`, `content/diagrams` (uno por examen, mismo id), `content/photos.json` y `content/photos/LISTA_DE_FOTOS.md`, y reescribe `index.json`. Es idempotente y conserva el `audioMs` real de los pasos cuyo texto no cambia. Los 3 exámenes originales no se tocan (51 por nivel en total).
- **Regla de contenido:** las Partes 3 y 4 comparten tema (`theme` del bloque). Las preguntas de la Parte 4 retoman los prompts de la burbuja. Dificultad: B1 concreto y personal; B2 compara y especula; C1 abstracto ("to what extent…").
- **Fotos:** `assets: ["b1-e01-a1"]` = `{nivel}-e{nn}-{candidato}{n}`. La descripción de cada una vive en `content/photos.json`; mientras no exista el archivo la app muestra el hueco con esa descripción. El archivo se deja en `content/photos/` con ese nombre (`.jpg/.jpeg/.png/.webp`) y `scripts/content/sync-photos.ts` lo copia a `apps/mobile/assets/photos/`; la app lo usa si está en el manifiesto (`photoCatalogProvider`).
- **Alternativa descartada por ahora:** R2 (`img/{nivel}/{examen}/{asset}.webp`, CLAUDE.md §5). Con ~600 fotos en el bundle la app crece; cuando se quiera, `PhotoGrid.imageUrlFor` ya acepta una URL remota y esta carpeta se puede subir tal cual.
- **Sustituido por D-036** (fotos comprimidas en R2): el bundle ya no lleva fotos.
- **Pendiente:** TTS de los 147 exámenes nuevos (`tts/generate.py` — hasta entonces `audioMs` es una estimación y no hay audio en R2) y re-seed de `exam_catalog`.

### D-036 · 2026-10-23 · Fotos de la Parte 2 comprimidas y en R2; subida masiva
- **Contexto:** 612 fotos (150 exámenes) en el bundle harían crecer mucho la app; CLAUDE.md §5 pide R2.
- **Compresión:** `scripts/content/build-photos.py` (Pillow) convierte lo que haya en `content/photos/` a WebP calidad 72, máx. 1024 px de lado, sin EXIF/GPS y girada según la orientación de la cámara → `content/.img-build/img/{nivel}/{examen}/{asset}.webp` (~50-120 KB por foto frente a 0,3-5 MB del original). Solo recodifica las nuevas o cambiadas y las saca de `.uploaded` para que se vuelvan a subir.
- **App:** las fotos se descargan en el lobby junto con el audio (`ExamMedia`, mismo `media-view-url`); un 404 (foto aún no subida) deja el hueco con su descripción. El audio se reutiliza de disco entre sesiones; las fotos se bajan siempre (pocas y pequeñas, y se pueden sustituir con la misma clave).
- **Subida:** `scripts/content/upload-r2.sh audio|img` usa `wrangler r2 bulk put` (lotes de 500, 20 en paralelo, reanudable con `.uploaded`). Antes era un `wrangler` por archivo (~10 s cada uno), inviable para ~11.600 audios.
- **Descartada:** mantener las fotos en el bundle con compresión (seguiría añadiendo ~40 MB a la app).

### D-037 · 2026-10-24 · Dos planes: Estándar (8 €) y Pro (10 €)
- **Contexto:** Alfonso añade un plan de 10 € con control total del examen. Amplía expresamente CLAUDE.md §13 («1 test + 8 €/mes»).
- **Decisión:** `entitlements.plan ∈ {standard, pro}`; `private.has_pro` = suscripción activa **y** `plan = 'pro'` (el test de prueba es Estándar). RevenueCat: entitlements `standard` y `pro`; el webhook lee `entitlement_ids` (`planOf`) y un evento sin ids no toca el plan. Mientras RevenueCat siga aplazado (D-020), `app_config.assume_paid_plan` fija el plan con el que nacen los usuarios; para probar, `update entitlements set plan='pro'` sobre una cuenta concreta. Ajustes muestra el plan y una hoja «Mejorar a Pro» con el botón de compra desactivado hasta que haya tienda.
- Plan de implementación completo: `docs/plans/2026-10-24-plan-pro.md`.

### D-038 · 2026-10-24 · Líder del examen
- `exam_sessions.leader_id` (+ `pro_a`/`pro_b`, visibles para los dos: hacen falta para ofrecer «Ceder el control»). `private.assign_leader` en crear sesión, presencia y tick: un solo Pro → dirige él; dos → uno al azar; ninguno → nadie. Ceder solo a un Pro (`partner_not_pro`). Si el líder lleva > 10 s desconectado y el otro es Pro, pasa al otro. Sin veto del otro, pero cada acción deja `last_control` y los dos ven un aviso.
- Encontrado por la suite: con `leader_id` nulo las comparaciones daban `null` (no `false`) y nunca se asignaba líder → `coalesce`.

### D-039 · 2026-10-24 · Reloj controlable (amplía D-003 y D-031)
- **Pausa:** `paused_at`; el tiempo transcurrido es `coalesce(paused_at, now) − exam_started_at`; reanudar suma la pausa al inicio y al fin del feedback. Solo en ventanas de habla (no mientras habla el lector). En pausa, los dos micros abiertos. Máx. 15 min (luego se reanuda solo); sesión máx. 3 h.
- **Saltos** (saltar lector, siguiente pregunta/parte, terminar, repetir, ir a parte): `exam_started_at = now − destino`, conservando la duración del feedback.
- **Minutos:** se reescribe `exam_sessions.schedule` (nunca el catálogo): ±30 s/+1/+2 min en el turno actual o fijar la duración de los turnos de la parte (mismo tipo y misma duración). Turnos de 10 s a 15 min, feedback ≤ 20 min.
- El fin del feedback es `feedback_ends_at` (antes `total + 5 min`).
- El micro se marca por clave `control_version:segmento` (`applied_key`), no con un índice monótono: así un salto **atrás** también se empuja a LiveKit.
- `control_version` + `expectedVersion` del cliente → `stale_control` ante dobles toques.
- Un solo contrato en dos lenguajes: `domain/exam/control.dart` y `private.ctl_apply` (función pura json→json) pasan los 24 casos de `content/fixtures/control-golden.json`.

### D-040 · 2026-10-24 · Cambio de examen dentro de la sesión
- En el lobby solo cambia el examen. Durante el examen: nueva `schedule`, pausa `switching`, precarga reiniciada; el tick arranca el nuevo (Parte 1, 3 s de margen) cuando los dos han descargado o a los 45 s. `join` envía la versión de contenido del móvil y no se acepta un examen que el compañero no tenga (`content_missing_partner`). `exam_history` (una fila por usuario y sesión) sigue al examen nuevo.
- **Práctica con compañero VIP simulado** (petición de Alfonso): solo con `kDebugMode`, en Inicio junto a «Practicar con compañero simulado»; `LocalExamController` aplica el mismo reductor en el móvil y el compañero simulado devuelve el control a los 5 s. **2026-10-28 (Alfonso):** también en las versiones release mientras dure la fase de pruebas (el `.ipa` del iPhone no es debug). Es práctica sin conexión: los controles Pro solo mueven el examen local. Antes de publicar, decidir si queda solo para Pro.
- Migraciones `20261024120418_pro_plan` y `20261024120548_session_control`, aplicadas con el MCP (Alfonso aprobó el aviso del `DROP FUNCTION` a tiempo; el script manual de reserva ya no hace falta).

### D-041 · 2026-10-24 · «Pregunta anterior» y dock del líder
- **Pregunta anterior** (`prev_step`): vuelve al principio del paso anterior (el examinador lo lee de nuevo); desde el feedback, a la última pregunta. En la primera pregunta, `out_of_range`. Mismo contrato en Dart y SQL (fixture con 28 casos; migración `20261024122328_control_prev_step`).
- **Rediseño de los controles (pedido por Alfonso, más intuitivo):** la hoja escondida tras ⚙ pasa a un **dock fijo** bajo el examen, como un reproductor: ⏮ Anterior · ⏯ (Pausar/Reanudar, o **Saltar** mientras habla el examinador: el botón principal hace lo que tiene sentido en cada momento) · ⏭ Siguiente · Sig. parte · Más. «Más» despliega en el sitio (máx. ⅓ de pantalla, con scroll) el tiempo del turno, la duración de los turnos, ir a una parte, repetir, cambiar de examen, ceder y terminar. En el feedback, el líder ve directamente ±tiempo y «Volver a la última pregunta». Mantiene la paleta y componentes del frontend original (no reabre D-032).

### D-042 · 2026-10-24 · Rúbrica de feedback privada
- **Contexto:** el rediseño 2.0 (§9.2 n.º 4) propone que cada candidato valore al otro. CLAUDE.md la dejaba fuera del MVP; Alfonso la elige expresamente entre las incorporaciones con backend.
- **Decisión:** `public.peer_ratings` (una fila por sesión y evaluador; 4 criterios de Cambridge, 1–5, todos opcionales). Solo se escribe con `public.rate_partner(sesión, …)`, `security definer`, que deduce a quién se valora a partir de la sesión (participante, examen empezado, compañero existente) y hace upsert. Lectura por RLS: el valorado y el evaluador. Perfil muestra «Lo que dicen de ti» (medias de las últimas 50). No es una nota oficial ni hay rankings.
- El asesor de Supabase avisa de que `authenticated` puede ejecutar una función `security definer`: es intencionado (es la única vía de escritura y valida la sesión). Migración `20261024160915_peer_ratings`, suite `08_peer_ratings.sql`.

### D-043 · 2026-10-24 · Frontend 2.0 «Turno y Reloj» (sustituye a D-032)
- **Contexto:** Alfonso encarga el rediseño completo con su propio documento y mockups (`docs/img/img_remaked/`). Ahora esa es la fuente de diseño.
- **Ajustes de Alfonso sobre el documento:** la tarjeta «papel» es **obsidiana** (negro-gris, texto claro) en los dos temas. Apple y Google aparecen en el login solo como interfaz: avisan de que llegarán pronto, y el email sigue siendo la vía real (D-022). Inicio mantiene el botón circular pulsante libre arriba y debajo los tiles «Próxima reunión» y «Practicar solo», sin racha, sin «Último examen» y sin contador de gente buscando. La mascota Pico está dibujada en código (CustomPainter con estados), no con Rive.
- **Técnica:**
  - Tokens en `core/theming/palette.dart` (contraste AA calculado por test) y `core/theming/tokens.dart`; piezas compartidas en `core/ui/` (`kit.dart`, `brand.dart`, `pico.dart`).
  - Las fuentes van en el bundle (OFL): Instrument Sans, Newsreader, IBM Plex Mono y Caveat para el diagrama manuscrito. Los iconos Phosphor también, como fuentes (MIT); el paquete `phosphor_flutter` 2.1.0 no compila en Flutter 3.47 porque `IconData` es `final`.
  - El cristal se hace con `BackdropFilter` propio, sin `liquid_glass_widgets`: menos dependencias y control del coste en Android. Tampoco se usan `rive`, `lottie` ni `google_fonts`.
- **Descartado por ahora:** Live Activity, widget de inicio, calentamiento de micro, resumen final y racha (no se eligieron).
- **2026-10-25 · Ondas del botón de Inicio en mandarina (Alfonso):** el círculo «Buscar pareja» sigue igual (cobalto, degradado, icono, texto, tamaño), pero sus ondas (`_Rings` en `search_pulse.dart`) usan `palette.roleB` en los dos temas, con la misma opacidad decreciente y sin animación si «Reducir movimiento» está activo. Solo afecta a Inicio: las ondas de «Buscando compañero…» no cambian.
- **2026-10-25 · Solo en vertical:** `SystemChrome.setPreferredOrientations([portraitUp])`, `android:screenOrientation="portrait"` y solo `UIInterfaceOrientationPortrait` en iOS. En iPad, `UIRequiresFullScreen` (sin Split View ni Slide Over) para poder limitar la orientación sin dejar de publicar en iPad (elección de Alfonso; descartado «solo iPhone»).

### D-044 · 2026-10-24 · Reportar y bloquear usuarios
- **Contexto:** Apple (guía 1.2) y Google Play exigen poder reportar y bloquear en apps donde desconocidos se comunican. Sin ello rechazan la app.
- **Decisión:** `user_blocks` y `user_reports`, con escritura solo por `block_user`, `unblock_user` y `report_user` (máximo 10 reportes al día por usuario). Un bloqueo afecta a los dos: no vuelven a emparejarse (`svc_match_enqueue`), no ven las ofertas del otro (política restrictiva), no pueden aceptarlas (`svc_offer_accept`) ni escribirse (política restrictiva en `chat_messages`), y se cancelan sus reuniones pendientes. Las políticas usan `public.is_blocked_with(otro)`, que solo informa de bloqueos entre quien pregunta y otra persona. Los reportes no los lee ningún cliente; se revisan a mano.
- **App:** «Reportar o bloquear» desde el chat, la sala de espera, el examen (dock y hoja «Más»), el feedback y la tarjeta de oferta. Bloquear durante una sesión la termina. Ajustes > Usuarios bloqueados permite desbloquear. Migración `20261025085249_report_block` (aplicada con el MCP el 2026-10-25 y renombrada a su versión, D-024), suite `09_report_block.sql`. El asesor solo añade los avisos esperados: `security definer` ejecutable por `authenticated` (son la única vía de escritura) y `user_reports` sin políticas (nadie la lee desde el cliente).

### D-045 · 2026-10-24 · Términos de uso y Política de privacidad (borrador)
- Textos en `apps/mobile/assets/legal/`, versión `2026-10-24` (= `termsVersion`, que se guarda al aceptar). Las notas para Alfonso empiezan por «> [REVISAR]»: el visor de la app las omite (`parseLegal`, con test). Se pueden leer sin cuenta (`/legal/terms`, `/legal/privacy`), desde la bienvenida, el registro (junto a la casilla) y Ajustes > Legal.
- Puntos abiertos para Alfonso: edad mínima de 14 años, titular, teléfono, URL pública y web de eliminación de cuenta. Lista completa en `docs/legal/PUBLICACION.md`.

### D-046 · 2026-10-25 · Agenda v2: reserva directa, compañeros y chat ligado a la reunión
- **Contexto:** Alfonso aprueba el análisis y el rediseño de `docs/plans/2026-10-25-agenda-rediseno.md`. Objetivo: quedar y hablar lo justo, repetir con compañeros habituales, no ser una red social. Amplía CLAUDE.md §8 (confirmación doble, varios aceptantes por oferta y chat permanente desaparecen).
- **Reserva directa:** elegir un hueco de una propuesta lo **reserva**: la reunión nace confirmada (`svc_offer_accept`). La propuesta sigue abierta con los huecos que queden y pasa a `filled` cuando no queda ninguno (`private.offer_has_free_slot`). El tablón tacha los huecos ya reservados con `offer_taken_slots` (solo horas, nunca quién). Retirar una propuesta no cancela lo ya reservado. La pregunta abierta «¿cerrar la propuesta entera al reservar?» se resolvió con la recomendación del documento (huecos restantes abiertos).
- **Cambiar hora:** vuelve a `pending` con el tick de quien la cambia; confirma solo el otro. Todas las horas (reservar, invitar, cambiar) en la rejilla de 30 min UTC (`private.valid_half_hour`).
- **Compañeros:** `companions` (una fila por pareja ordenada). Solo se añade a alguien con quien has llegado al feedback de un examen (`companion_add(sesión)`; vale `feedback` porque «Terminar» sale antes de `ended`). Mutuo = los dos se han añadido. Máx. 20. `companion_remove` limpia mi lado (sin `DELETE`). `my_companions()` devuelve solo filas de quien pregunta, con exámenes juntos y la última sesión (para «Añadir también»).
- **Invitación directa** (`meeting-actions {invite}` → `svc_meeting_invite`): solo entre compañeros mutuos, sin bloqueo, sin solape, máx. 3 pendientes. Nace con el tick de quien invita.
- **Chat:** política restrictiva `chat_messages_meeting_alive`: se escribe si la reunión está `pending`/`confirmed`/`done`/`no_show` y no han pasado 2 h desde su hora. Mensajes ≤ 500 caracteres (`check ... not valid`, los antiguos siguen siendo válidos). `svc_cron_housekeeping` borra los chats de reuniones terminadas hace más de 30 días, salvo si hay un reporte abierto sobre ellos.
- **Bloquear (D-044)** además anula el vínculo de compañeros; las invitaciones pendientes se cancelan con el resto de reuniones.
- **App:** Agenda con dos pestañas («Mis exámenes»: compañeros, te toca, próximos, mis propuestas con quién reservó, anteriores plegadas; «Buscar horario»: tira de días y huecos tocables en cada tarjeta), botón «＋ Proponer» en la cabecera, tarjeta del chat con pasos y una sola acción principal, respuestas rápidas, chat de solo lectura al cerrarse, hoja de invitación, y en el feedback/fin del examen «Añadir a compañeros» / «Repetir con…» (`/agenda?invite=`).
- Migración `20261025160537_agenda_v2` (aplicada con el MCP), suites `04_agenda.sql` (reescrita) y `10_companions.sql`.

### D-047 · 2026-10-25 · Fotos de la Parte 2: Pixabay, compresión con tope y caché en el móvil
- **Banco:** Pexels no da claves ahora mismo; Alfonso elige **Pixabay** (Pixabay Content License: uso comercial sin atribución; sus normas piden descargar en vez de enlazar y cachear 24 h, que es lo que hacemos). Descartados: Openverse/Wikimedia (fotos personales con gente reconocible sin cesión de imagen) y Unsplash (su API exige enlazar desde sus servidores).
- **Flujo con revisión humana** (`scripts/content/photos_pixabay.py`): `search` hace hojas de contacto por turno de candidato (las fotos que se comparan, juntas); `pick id=n` descarga la elegida a 1280 px y apunta autor y página en `content/LICENSES.md`; `ai id` la manda a `content/photos/PROMPTS_IA.md` con un prompt listo (realista, 4:3, sin texto ni logos). Clave en `PIXABAY_API_KEY` (entorno o `.env`, nunca en el repo).
- **Para no cargar Cloudflare:** `build-photos.py` recorta todas a 4:3 (las parejas se comparan mejor) y baja la calidad WebP de 72 hasta 50 como mucho, hasta que la foto quepa en 110 KB (612 fotos ≈ 50 MB en R2, lejos de los 10 GB gratuitos). La app reutiliza en disco cada foto descargada durante 14 días (`photoCacheTtl`, antes se pedía en cada sesión): cada reutilización ahorra una lectura de R2 y una URL firmada de `media-view-url`. El audio sigue reutilizándose siempre. Una foto sustituida con la misma clave llega a todos en 14 días como mucho.
- **Resultado (2026-10-28):** 416 de 612 en R2; 196 a la lista de IA (sobre todo C1: escenas abstractas o muy concretas que los bancos no tienen). Palabras clave a mano por foto en `content/photos/queries.json`; se descartan las imágenes que Pixabay marca como generadas por IA. Las URLs de imagen de Pixabay caducan en 24 h: `pick` pide una nueva a la API por id. Corregido de paso: `build-photos.py` escribía `.uploaded` con CRLF en Windows y `upload-r2.sh` volvía a subir todo.
- **Las 196 restantes, con IA (2026-10-28):** Alfonso descarta Google Imágenes (derechos de autor y de imagen) y aporta una clave de OpenAI con un presupuesto de 8 €. `scripts/content/photos_openai.py` lleva la cuenta del gasto real (tokens de cada respuesta → $) en `content/.openai/spend.json` y se niega a pasar de un tope (`--cap`, 7 $ por defecto). Modelo `gpt-image-1-mini`, calidad media, 1536×1024 (≈ 0,0127 $ por foto): 199 llamadas, **2,49 $**. Primero una de prueba, luego las 43 que completaban exámenes y después el resto, todo revisado en hojas de contacto. Rehechas 3: una con el emblema de la Cruz Roja (protegido) y dos bloqueadas por el filtro de contenido («niños vestidos de soldado», «refugiados») con otra redacción.
