# Publicación en App Store y Google Play: qué falta

Estado a 24 de octubre de 2026. Los textos legales están en `apps/mobile/assets/legal/` (terminos.md y privacidad.md). Las notas `[REVISAR]` de esos archivos no se muestran en la app.

## Ya resuelto en la app

- Términos de uso y Política de privacidad legibles dentro de la app, sin cuenta (pantalla de bienvenida, registro y Ajustes > Legal).
- Aceptación expresa con casilla en el registro. Se guarda la versión (`2026-10-24`) y la fecha en `profiles_private`.
- Eliminación de la cuenta desde la app (Ajustes > Eliminar cuenta). La piden Apple (guía 5.1.1(v)) y Google.
- Reportar y bloquear usuarios desde el chat, la sala de espera, el examen, el feedback y la Agenda; lista de bloqueados en Ajustes. La exigen Apple (guía 1.2) y la política de contenido generado por usuarios de Google Play.
- Aviso de no afiliación con Cambridge en la bienvenida y en Ajustes.
- Explicaciones de los permisos en iOS (micrófono, fotos, cámara) y nombre visible «Speaking P2P» en los dos sistemas.

## Decisiones tuyas antes de enviar

1. **Edad mínima.** 14 años solo funciona bien en España y choca con la clasificación por edad que probablemente salga (comunicación libre entre usuarios). Ver la nota del apartado 4 de los Términos. Si cambias la edad, hay que cambiarla también en la app (`Validators.isOldEnough`, en `domain/account/account.dart`), en el servidor (el trigger que lanza `underage` en `profiles_private`) y en los dos textos.
2. **Titular.** Nombre o razón social, NIF, domicilio y correo de contacto para los huecos [●].
3. **Teléfono.** Quitarlo del registro o justificar para qué se usa.
4. **Nombre comercial.** Si cambia (YourTurn, SpeakBeak…), sustituir «Speaking P2P» en los textos, en `appName` y en el nombre visible de Android e iOS.

## Pendiente técnico

- **Una URL pública con la Política de privacidad** (y mejor también con los Términos). La piden las dos tiendas en la ficha. Opción sencilla: publicar los dos .md como páginas en Cloudflare Pages o GitHub Pages con un dominio propio.
- **Una web para pedir la eliminación de la cuenta sin la app.** Google Play la exige en el formulario de seguridad de los datos. Puede ser una página con el procedimiento («escribe desde el correo de tu cuenta a …»).
- **Volver a pedir la aceptación** cuando cambie `termsVersion` (hoy solo se pide en el registro).
- **iOS: archivo PrivacyInfo.xcprivacy** de la app. Los plugins traen el suyo, pero conviene añadir el de la app (UserDefaults, motivo CA92.1) desde Xcode.
- **iOS: Sign in with Apple.** Si se activa el acceso con Google, Apple exige ofrecer también Sign in with Apple (guía 4.8). Hoy solo hay email, así que no aplica.
- **Pagos (RevenueCat).** Pantalla de compra con el texto de renovación automática, precio y periodo, y enlaces a los Términos y a la Privacidad (Apple lo revisa en la guía 3.1.2).
- **Revisión de reportes.** Decidir quién los mira y en qué plazo. Hoy están en la tabla `user_reports` de Supabase, sin panel.
- **Interruptores de desarrollo.** Antes de publicar, apagar `dev_instant_rooms`, `dev_session_skip` y `assume_paid`, y compilar en modo release: los botones de depuración solo salen en builds de debug.

## Formularios de las tiendas (respuestas orientativas)

**Google Play · Seguridad de los datos**
- Datos recogidos: correo electrónico, ID de usuario, nombre de usuario, fotos (opcional), grabaciones de voz (opcional, con consentimiento), mensajes de la app, otros contenidos del usuario (valoraciones), historial de compras, interacciones con la app y diagnósticos.
- Cifrados en tránsito: sí. El usuario puede pedir la eliminación: sí, desde la app y desde la web del punto anterior.
- No se comparten con terceros con fines publicitarios (cambia si se integra AdMob).

**App Store · Privacidad de la app**
- Datos vinculados al usuario: información de contacto (correo y, si se mantiene, teléfono), contenido del usuario (audio, fotos, mensajes, otros), identificadores (ID de usuario), compras, uso.
- Rastreo: no (cambia si se integra AdMob con anuncios personalizados: entonces hace falta App Tracking Transparency).

**Clasificación por edad.** Responder «sí» a comunicación entre usuarios y contenido generado por usuarios. El resultado condiciona la edad mínima (decisión 1).

**Cuenta de prueba para la revisión.** Apple y Google la piden: crea dos cuentas de prueba con el plan activo, porque los revisores necesitan probar una sesión, y explica en las notas de revisión que la app necesita dos personas (o que pueden usar «Practicar solo»).
