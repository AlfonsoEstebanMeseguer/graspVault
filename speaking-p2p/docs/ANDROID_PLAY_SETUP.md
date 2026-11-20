# Android en Google Play — guía de configuración (D-068)

| Qué | Dónde vive | ¿Secreto? |
|---|---|---|
| Keystore de subida (`upload-keystore.jks`, alias `upload`) | `C:\Users\alfon\Documents\MirloTalk-secretos\android\` + secreto de GitHub `ANDROID_KEYSTORE_BASE64` | **Sí** |
| Contraseña del keystore | `keystore-password.txt` en esa carpeta + secreto `ANDROID_KEYSTORE_PASSWORD` | **Sí** |
| `android/key.properties` | Solo en este PC, gitignorado; apunta al keystore | **Sí** |
| Cuenta de servicio de Play | Secreto `PLAY_SERVICE_ACCOUNT_JSON` (opcional) | **Sí** |

Datos fijos:
- **Paquete:** `com.speakingp2p.speaking_p2p`
- **SHA-1 de la clave de subida:** `02:6A:C1:40:B1:A1:A9:A6:CB:73:31:18:AB:4E:5E:22:02:A0:FB:4D`
- **SHA-1 de debug (este PC):** `5F:3D:A3:83:3D:45:0A:88:25:A2:A6:2C:0D:C6:4E:71:C6:EC:A1:60`

Si se pierde el keystore de subida no se pierde la app (Play App Signing guarda la clave de firma real), pero hay que pedir a Google un reseteo de la clave de subida. Haz una copia de seguridad privada de la carpeta.

## 1. Cuenta de Play Console
1. <https://play.google.com/console/signup> → cuenta **personal** → pago único de 25 $.
2. Verificación de identidad (DNI) y de un teléfono Android con la app Play Console. Puede tardar unos días.
3. **Cuentas personales nuevas:** para pasar a producción, Google exige antes una **prueba cerrada con al menos 12 testers durante 14 días seguidos**. La prueba **interna** (hasta 100 testers) no tiene ese requisito y sirve para probar ya.

## 2. Crear la app
Play Console → **Crear aplicación**: nombre MirloTalk, idioma español, **Aplicación**, **Gratis**, aceptar las declaraciones.

## 3. Primera subida (a mano)
1. GitHub → Actions → **speaking-p2p Google Play** → Run workflow. Sin `PLAY_SERVICE_ACCOUNT_JSON` solo genera el artefacto `MirloTalk-<n>-aab`; descárgalo y descomprímelo.
2. Play Console → app → **Probar y publicar → Pruebas → Prueba interna** → Crear versión.
3. Acepta **Play App Signing** (Google genera y guarda la clave de firma de la app) → sube el `.aab` → Guardar → Revisar → Publicar.
4. Pestaña **Testers**: crea una lista con tu Gmail y copia el **enlace de participación**; ábrelo en el Redmi y descarga desde Play.

## 4. Google Sign-In con las claves de Play
Play vuelve a firmar la app con **su** clave, así que el login con Google falla hasta registrar ese SHA-1:
1. Play Console → **Probar y publicar → Configuración → Integridad de la app → Firma de apps** → copia el **SHA-1 de la clave de firma de apps**.
2. Google Cloud → **Credenciales → Crear credenciales → ID de cliente de OAuth → Android**, paquete `com.speakingp2p.speaking_p2p`, ese SHA-1. Nada que copiar.
3. Opcional: otro cliente Android con el SHA-1 de la **clave de subida** (arriba), para que también funcionen los release firmados en local.
4. Supabase no cambia: el ID de cliente que valida es el web.

## 5. Subidas automáticas (opcional)
1. Google Cloud (proyecto MirloTalk) → **APIs y servicios → Biblioteca** → habilita **Google Play Android Developer API**.
2. **IAM → Cuentas de servicio → Crear**: nombre `play-ci`, sin roles → crear. En la cuenta → **Claves → Agregar clave → JSON** (se descarga una vez; guárdala en la carpeta de secretos).
3. Play Console → **Usuarios y permisos → Invitar usuario** → el correo de la cuenta de servicio → permisos de la app MirloTalk: *Ver información de la app*, *Publicar en canales de prueba* (y *Gestionar producción* cuando toque).
4. `gh secret set PLAY_SERVICE_ACCOUNT_JSON -R AlfonsoEstebanMeseguer/graspVault < <ruta del .json>`
5. Desde entonces el workflow sube solo a la pista elegida (`internal` por defecto). Mientras la app no se haya publicado nunca, usa `status=draft`.

- El `versionCode` es el número de ejecución del workflow, así que siempre crece. Los builds locales usan el de `pubspec.yaml` (1): no los subas a Play.
