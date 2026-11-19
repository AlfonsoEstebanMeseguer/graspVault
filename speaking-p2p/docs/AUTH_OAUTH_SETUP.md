# Login con Google y Apple — guía de configuración (D-062)

El código ya está hecho. Cada proveedor se enciende solo cuando su configuración existe; mientras tanto, el botón dice «llegará pronto».

| Qué | Dónde vive | ¿Secreto? |
|---|---|---|
| Client IDs de Google (web, iOS) | `apps/mobile/env/dev.json` | No, son públicos |
| Client secret de Google | Supabase Dashboard → Auth → Providers → Google | **Sí**, nunca en el repo |
| `APPLE_SIGN_IN=true` | `apps/mobile/env/dev.json` | No |
| Clave `.p8` de Apple, Team ID, Key ID | Supabase → Edge Functions → Secrets | **Sí** (la `.p8`) |

Datos fijos del proyecto:
- **Bundle ID iOS:** `com.speakingp2p.speakingP2p`
- **Paquete Android:** `com.speakingp2p.speaking_p2p`
- **SHA-1 de la clave de debug de este PC** (la que firma también el `--release` hoy, ver `android/app/build.gradle.kts`): `5F:3D:A3:83:3D:45:0A:88:25:A2:A6:2C:0D:C6:4E:71:C6:EC:A1:60`
- **Callback de Supabase:** `https://<ref>.supabase.co/auth/v1/callback` (sale en Dashboard → Auth → Providers → Google)

---

## 1. Google (se puede hacer hoy, es inmediato)

### 1.1 Proyecto y pantalla de consentimiento
1. <https://console.cloud.google.com> → crear el proyecto **MirloTalk**.
2. **APIs y servicios → Pantalla de consentimiento de OAuth** (en la consola nueva: «Google Auth Platform → Branding»):
   - Tipo de usuario: **Externo**.
   - Nombre de la app: MirloTalk. Correo de soporte: el tuyo.
   - Dominios autorizados: `supabase.co` (y `mirlotalk.app` cuando exista).
   - Enlaces a la política de privacidad y a los términos (cuando estén publicados en web).
   - Ámbitos: solo `openid`, `email` y `profile`, que no requieren verificación de Google.
   - Mientras esté en modo **Testing**, añade tu cuenta en «Usuarios de prueba». Para publicar, pulsa **Publicar app**. Con solo esos ámbitos no hay revisión.

### 1.2 Tres clientes OAuth (Credenciales → Crear credenciales → ID de cliente de OAuth)
1. **Aplicación web** → nombre «MirloTalk Supabase».
   - URIs de redirección autorizados: el callback de Supabase de arriba.
   - Guarda el **Client ID** (→ `GOOGLE_WEB_CLIENT_ID`) y el **Client secret** (→ solo en Supabase).
2. **Android** → paquete `com.speakingp2p.speaking_p2p` y el SHA-1 de arriba.
   - No da nada que copiar: basta con que exista.
   - Cuando haya una clave de *release* propia o se publique en Play (Play App Signing), crea otro cliente Android con **ese** SHA-1 (Play Console → Integridad de la app).
3. **iOS** → Bundle ID `com.speakingp2p.speakingP2p`.
   - Guarda el **Client ID** (→ `GOOGLE_IOS_CLIENT_ID`).

### 1.3 Supabase (proyecto `SpeakingApp`)
Dashboard → **Authentication → Sign In / Providers → Google**:
- Enable: **on**.
- **Client IDs:** `<GOOGLE_WEB_CLIENT_ID>,<GOOGLE_IOS_CLIENT_ID>` (los dos, separados por coma).
- **Client Secret:** el del cliente web.
- **Skip nonce check:** **off**. La app manda el nonce. Si en iOS fallara con «nonce mismatch», actívalo y avísame.
- Si el login falla con *«No se ha podido iniciar sesión»* y el log de Auth dice Unacceptable audience in id_token, falta el ID web en **Client IDs** (pasó el 2026-11-19). Van los dos IDs separados por una coma, sin espacios.

### 1.4 App
En `apps/mobile/env/dev.json` añade:
```json
"GOOGLE_WEB_CLIENT_ID": "xxxx-web.apps.googleusercontent.com",
"GOOGLE_IOS_CLIENT_ID": "xxxx-ios.apps.googleusercontent.com"
```
- El URL scheme de iOS se genera solo a partir de ese valor: `tool/ios_auth_config.dart` lo hace en el workflow de iOS.
- La app **se niega a arrancar** si pegas el *secret* (`GOCSPX-…`) en lugar del ID.
- Google en iOS funciona también con el `.ipa` sin firmar + Sideloadly (no necesita capability).

---

## 2. Apple (requiere Apple Developer Program, 99 €/año)

La inscripción suele tardar de 24 a 48 h en aprobarse. Hasta entonces, deja `APPLE_SIGN_IN` sin poner y el botón dirá «llegará pronto».

### 2.1 Developer portal (<https://developer.apple.com/account>)
1. **Certificates, IDs & Profiles → Identifiers → App IDs** → crea o edita `com.speakingp2p.speakingP2p` y marca **Sign In with Apple** (*Enable as a primary App ID*).
2. **Keys → +** → nombre «MirloTalk SIWA», marca **Sign In with Apple** → Configure → App ID primario: el de arriba → Register.
   - Descarga el `.p8`. **Solo se puede descargar una vez.** Guárdalo fuera del repo.
   - Apunta el **Key ID** (10 caracteres) y tu **Team ID** (arriba a la derecha, Membership).
3. No hace falta un Services ID: el login es nativo y solo en iOS (D-062).

### 2.2 Supabase
1. Dashboard → **Authentication → Providers → Apple**:
   - Enable: **on**.
   - **Client IDs:** `com.speakingp2p.speakingP2p`.
   - Secret Key: vacío (solo hace falta para el flujo web, que no usamos).
2. Edge Functions → **Secrets** (para revocar el token al borrar la cuenta, guía 5.1.1(v) de App Store):
   - `APPLE_TEAM_ID`
   - `APPLE_KEY_ID`
   - `APPLE_CLIENT_ID` = `com.speakingp2p.speakingP2p`
   - `APPLE_PRIVATE_KEY` = el contenido entero del `.p8`, incluidas las líneas `-----BEGIN/END PRIVATE KEY-----`
3. Redespliega `account-delete`. Sin esos secretos, el borrado funciona igual pero no revoca, y deja un aviso en los logs.

### 2.3 App y firma
1. `env/dev.json` → `"APPLE_SIGN_IN": "true"`.
2. `ios/Runner/Runner.entitlements` ya declara la capability. **Solo funciona en un build firmado con un perfil que la incluya**:
   - El `.ipa` sin firmar + Sideloadly con Apple ID gratuito **no** sirve (Apple devuelve el error 1000).
   - Con la cuenta de pago, la vía buena es firmar en CI y subir a TestFlight. Es el siguiente paso a montar en el workflow (certificado de distribución + perfil como secretos de GitHub).

---

## 3. Cómo se comporta

- **Registro = login.** Google o Apple crean la cuenta si no existe, y el router la lleva al onboarding (`profiles` vacío).
- **Mismo email, varias vías.** Si alguien se registró con email y luego entra con Google con el mismo email verificado, Supabase une las identidades: es la misma cuenta.
- **Apple con «Ocultar mi correo».** Se guarda el correo de reenvío `@privaterelay.appleid.com`. La lápida del test de prueba (D-007) usa ese correo, que es estable para nuestra app.
- **Apple solo en iOS.** Una cuenta creada con Apple no puede entrar desde Android (D-062, riesgo aceptado). Si se pide, se añade el flujo web con un Services ID.
- **Borrar la cuenta:**
  - Email: pide la contraseña.
  - Google o Apple: vuelve a abrir la hoja del proveedor.
  - Si con esa hoja se entra en **otra** cuenta, no se borra nada (`reauth_mismatch`).
  - Apple envía además el `authorizationCode` para revocar el token.
- **Cerrar sesión** también olvida la cuenta de Google elegida, así que la próxima vez sale el selector.

## 4. Prueba rápida
1. Android (emulador Pixel_5 o el Xiaomi): `flutter run --dart-define-from-file=env/dev.json` → «Continuar con Google» → onboarding → Inicio.
2. Ajustes → Eliminar cuenta: solo pide la frase y, al confirmar, vuelve a abrir la hoja de Google.
3. iOS: lanzar el workflow «speaking-p2p iOS» → Sideloadly → probar Google. Apple, cuando haya un build firmado.
