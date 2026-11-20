# Puesta en marcha de los servicios

> Regla de oro (vault, higiene de secretos): **nunca pegues un valor secreto en el chat**. Los secretos van directamente al panel de Supabase (Edge Functions → Secrets), a Supabase Vault o a los secrets de GitHub. A mí solo me hace falta saber *que existen* y sus **nombres** (ver `.env.example`).

Orden recomendado (cada paso desbloquea un hito):

## 1. Supabase (desbloquea hitos 1, 3, 4, 5)
1. supabase.com → **New project** → región **EU (Frankfurt o Irlanda)**. Apunta el *Reference ID* (no es secreto).
2. Conecta el **MCP de Supabase** a esta sesión de Claude Code (claude.ai → Settings → Connectors). Con él aplico las migraciones, compruebo grants en `information_schema` y versiones reales de las funciones (`list_edge_functions`), como en Grasp.
3. Database → Extensions: activa **pg_cron** y **pg_net**.
4. SQL Editor (no lo pegues en el chat), crea los dos secretos del cron:
   ```sql
   select vault.create_secret(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'internal_cron_token');
   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
   select encode(sha256(convert_to(decrypted_secret, 'UTF8')), 'hex') from vault.decrypted_secrets where name = 'internal_cron_token';
   ```
   El último valor (el **hash**, no el token) va a Edge Functions → Secrets como `INTERNAL_CRON_TOKEN_SHA256`.
5. Authentication → Providers: **desactiva Email**, activa **Google** (paso 2).

## 2. Google Sign-In (hito 1)
1. console.cloud.google.com → proyecto nuevo → APIs & Services → OAuth consent screen (External, nombre de la app, email de soporte).
2. Credentials → Create OAuth client ID, **tres veces**:
   - **Web application** → su *Client ID* y *Secret* van a Supabase (Auth → Google). El Client ID también va a la app como `GOOGLE_WEB_CLIENT_ID`.
   - **Android** → package `com.speakingp2p.speaking_p2p` + SHA-1 de tu keystore de debug y de release.
   - **iOS** → bundle id `com.speakingp2p.speakingP2p` → `GOOGLE_IOS_CLIENT_ID`.
3. No hace falta activar ninguna API extra.

## 3. LiveKit Cloud (hito 3)
1. cloud.livekit.io → proyecto nuevo (puedes reutilizar la cuenta de Grasp, pero **proyecto distinto**).
2. Settings → Keys → crea una API key: `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` → Supabase Edge Function Secrets.
3. Settings → Webhooks → URL `https://<ref>.supabase.co/functions/v1/livekit-webhook`, firmado con esa misma key.

## 4. Cloudflare R2 (hitos 1, 2, 7)
1. R2 → crea **tres** buckets en jurisdicción **EU**: `speaking-content`, `speaking-media`, `speaking-recordings`.
2. `speaking-content` → Settings → **Custom domain** (p. ej. `cdn.tudominio`) → ese URL es `CONTENT_CDN_URL`. Es público a propósito (audio y fotos de examen).
3. `speaking-recordings` → Settings → **Object lifecycle rules** → borrar objetos a los **30 días**.
4. Manage API tokens → dos tokens *Object Read & Write*: uno limitado a `speaking-media` (+ `speaking-content` para subir contenido) y **otro solo para `speaking-recordings`** (se le entrega a LiveKit).
5. Ojo (vault): el endpoint **no** lleva el nombre del bucket y, para buckets EU, lleva `.eu.` (`https://<account>.eu.r2.cloudflarestorage.com`). Sin `.eu.` todo devuelve 403.

## 5. RevenueCat + tiendas (hito 6)
1. App Store Connect y Google Play Console: suscripción mensual **8 €** (mismo identificador en ambas, p. ej. `monthly_8`).
2. RevenueCat → proyecto → apps iOS/Android → entitlement `pro` con ese producto.
3. Integrations → Webhooks → URL `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`, cabecera *Authorization* con un valor aleatorio largo. En Supabase guarda **solo su SHA-256** como `REVENUECAT_WEBHOOK_AUTH_SHA256`.

## 6. Resto
- **Firebase** (push): proyecto → Cloud Messaging → cuenta de servicio JSON → `FCM_SERVICE_ACCOUNT_JSON`; sube la clave APNs de Apple.
- **AdMob**: app iOS + Android y un bloque *App Open* → ids en la app.
- **Sentry** (2 proyectos: Flutter y Deno) y **PostHog** (EU cloud).
- **TTS** (hito 2/7): elige proveedor. Recomendación: **Google Cloud Text-to-Speech (voces Neural2/Studio en-GB)**: buena calidad, precio bajo por carácter, licencia comercial clara. Alternativa más natural y cara: ElevenLabs.
- **GitHub**: los workflows no necesitan secretos todavía.

## Lo que haré yo cuando esté cada pieza
- Supabase + MCP → `supabase db push`, auditoría de grants en el entorno real, despliegue de funciones y prueba con `curl` de cada una.
- LiveKit → copiar una respuesta **real** de `UpdateParticipant` al fixture de tests (lección del vault) y probar con dos dispositivos.
