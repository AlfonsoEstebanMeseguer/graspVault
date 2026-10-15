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
