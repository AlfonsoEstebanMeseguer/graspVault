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
