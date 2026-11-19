# Términos y Privacidad: lo que falta antes de publicar

Los dos documentos legales (`apps/mobile/assets/legal/terminos.md` y `privacidad.md`)
están redactados y listos para enseñarse en la app. Esta nota recoge lo que **no puedo
decidir por ti** y lo que conviene revisar antes de subir la app a App Store y Google Play.

Las notas internas `[REVISAR]` que antes vivían dentro de los dos `.md` se han movido aquí:
la app ya no las muestra y los documentos quedan limpios. Los huecos que siguen en los textos
aparecen como `[por completar antes de publicar]`.

Versión de los documentos: **2026-11-19** (constante `termsVersion` en
`apps/mobile/lib/domain/account/account.dart`). Si cambias algo relevante, sube también esa fecha.

---

## 1. Datos del titular — ✅ rellenado el 2026-11-19

Términos (cabecera LSSI) y Política (§1): Alfonso Esteban Meseguer García, NIF 54633962S,
Calle Júcar, 10, La Alcayna, 30507 Molina de Segura (Murcia). Persona física (autónomo), así que
no hay razón social ni datos registrales. **Confirma el código postal y el municipio**, que
completé yo. Si más adelante creas una sociedad, cambia estos datos y sube `termsVersion`.

## 2. Correos de contacto (bloqueante)

Los documentos y la app usan `soporte@mirlotalk.app` y `privacidad@mirlotalk.app`, que **no existen
todavía** (no hay dominio). Sin un buzón que funcione no se cumple el art. 10 LSSI ni el plazo de un
mes del RGPD, y Apple y Google piden un contacto real en la ficha.

Opciones, de mejor a más rápida:
1. **Registrar `mirlotalk.app`** (unos 15 €/año; `.app` exige HTTPS, lo que también sirve para la web
   de la Política que piden las tiendas) y crear los dos buzones. Con Cloudflare Email Routing (ya
   usas Cloudflare) se reenvían gratis a tu correo personal sin que este aparezca en ningún sitio.
2. Una cuenta de Gmail dedicada solo a la app (p. ej. `mirlotalk.soporte@gmail.com`), y cambiar las
   dos direcciones en los documentos y en `errorBanned`.

Cuando lo decidas, dime las direcciones y las cambio en todos los sitios.

## 3. Edad mínima — ✅ 16 años desde el 2026-11-19 (D-066)

Subida de 14 a 16: es la edad de consentimiento digital más alta de la UE (art. 8 RGPD), así que vale
en todos los países, y encaja con la clasificación 16+ que suelen dar las tiendas a las llamadas entre
desconocidos. Cambiado en el formulario, en el servidor (`20261119170000_min_age_16.sql`, aplicada),
en los textos de la app y en los dos documentos. Ningún usuario actual tenía menos de 16.

En el cuestionario de clasificación de Apple y Google, declara **comunicación sin moderar entre
usuarios** y público objetivo **16+** (no marques menores en Google Play: evita la Families Policy).

## 4. Marcas (Cambridge)

Los documentos dejan claro que la app es independiente y no está afiliada a Cambridge, y que los
nombres de examen se usan solo de forma descriptiva. Conviene que un abogado de marcas confirme el
uso de «B1 Preliminary», «B2 First» y «C1 Advanced» en la ficha de las tiendas y en la app. La
práctica segura: usarlos solo descriptivamente («para preparar el B2 First»), sin logotipos ni la
tipografía de Cambridge.

## 5. Teléfono — ✅ resuelto el 2026-11-19 (D-065)

Eliminado: la app ya no lo pide, el servidor ya no lo acepta y los números guardados se borraron
con la columna (migración `20261119160000_drop_phone_bans.sql`). La Política dice «No le pedimos el
número de teléfono».

## 6. Pagos y suscripción (RevenueCat aún no integrado)

Los Términos ya describen los planes (Estándar 8 €, Pro 10 €), la renovación automática y el derecho
de desistimiento. Antes de activar pagos:

- Comprobar que **precios, texto de renovación automática y desistimiento** coinciden con lo
  configurado en App Store Connect y Google Play. Apple exige el texto de renovación casi literal en
  la pantalla de compra.
- Si ofreces una **prueba gratuita gestionada por la tienda** (p. ej. 7 días), hay que describirla.
- Añadir **RevenueCat** como encargado del tratamiento en el apartado 5 de Privacidad.

## 7. Publicidad (AdMob aún no integrado)

Si integras el App Open Ad:

- En el EEE, Google exige una **plataforma de consentimiento certificada** (su UMP) antes de mostrar
  anuncios personalizados.
- A menores solo anuncios **no personalizados**.
- En iOS, pedir el permiso de seguimiento (**ATT**) si se usa el identificador publicitario.
- Añadir AdMob al apartado 5 de Privacidad.

Si decides no poner publicidad, hay que **borrar el apartado 14 de los Términos** y la mención
correspondiente en Privacidad.

## 8. Moderación y Reglamento de Servicios Digitales (DSA) — plazo fijado el 2026-11-19 (D-065)

Los Términos (10.2) prometen ahora revisar los reportes **en 72 horas como máximo**. Cubre el
mecanismo de notificación (art. 16 DSA) y la motivación de las decisiones (art. 17), de las que las
microempresas no están exentas.

Queda por tu parte, como proceso:
- Revisar `user_reports` (estado `open`) al menos cada 72 h, también en vacaciones.
- Comunicar cada medida al usuario con los motivos **antes** de aplicarla, por correo desde
  `soporte@mirlotalk.app`.
- Para una baja definitiva: `select private.ban_user('<uuid>', '<motivo>');` en el editor SQL
  (ver §14).

## 9. Analítica y errores (Sentry / PostHog) — redactado el 2026-11-19 (D-064)

Ya están en la Política (apartados 2.2, 3, 4 y 5.2). Decisión de Alfonso: **interés legítimo con
opt-out** («Compartir estadísticas de uso» en Ajustes, activado por defecto), no consentimiento.
Riesgo aceptado: la AEPD suele pedir consentimiento para analítica que guarda un identificador en
el dispositivo; si se quiere el mínimo riesgo, cambiar a opt-in en el onboarding.

Queda por verificar o hacer:
- **Plazos** escritos: errores hasta 90 días, estadísticas hasta 12 meses. Comprobar la retención
  real del plan de Sentry y de PostHog y ajustarla en sus paneles si es mayor.
- En **Sentry**: activar *Prevent Storing of IP Addresses* y *Data Scrubber* en los dos proyectos.
- En **PostHog**: activar *Discard client IP data*. Session replay y encuestas ya van apagados en la app.
- **DPA**: aceptar el contrato de encargo en los paneles de Sentry y PostHog.
- **Borrado de cuenta** ✅ código (D-066): `account-delete` pide a PostHog borrar la persona y sus
  eventos (`persons/bulk_delete`). Se activa al crear en Supabase los secretos
  `POSTHOG_PERSONAL_API_KEY` (clave personal con permiso *person:write*) y `POSTHOG_PROJECT_ID`.
  Sin ellos no hace nada; un fallo llega a Sentry y no frena el borrado.
- **Re-aceptación** ✅ (punto 11).

## 10. Proveedores: regiones y contratos (DPA)

- Confirmar en el panel de **LiveKit Cloud** y **Cloudflare R2** la región donde se procesan y
  guardan los datos. Si se puede, elegir la **UE** (R2 permite jurisdicción UE).
- Firmar un **contrato de encargo del tratamiento (DPA)** con cada proveedor del apartado 5. La
  mayoría lo ofrece en sus condiciones.
- Si el correo de confirmación no lo envía Supabase, añadir el proveedor de email.
- Llevar el **registro de actividades de tratamiento** (art. 30 RGPD). No es obligatorio nombrar un
  Delegado de Protección de Datos (DPO) por el volumen y tipo de datos.

## 11. Re-aceptación cuando cambie la versión — ✅ implementado el 2026-11-19 (D-066)

Si la versión aceptada (`profiles_private.terms_version`) es anterior a `termsVersion`, la app abre
`TermsUpdateScreen` y no deja pasar hasta aceptar (o cerrar sesión). La aceptación va por
`public.accept_terms(version)` (migración `20261119180000_terms_reaccept.sql`, aplicada), que pone la
fecha del servidor. Las versiones son fechas ISO: una app antigua nunca pide «volver atrás».
Los 3 usuarios actuales (versiones 2026-10-15 y 2026-11-02) verán la pantalla con el próximo build.

**Regla:** cada cambio relevante de los documentos = subir `termsVersion` a la fecha del cambio.

## 12. Transferencias internacionales — revisado el 2026-11-19

La Política (§6) ya nombra el mecanismo de cada uno:
- **Marco de Privacidad de Datos UE-EE. UU.** (según sus propias páginas): LiveKit, Cloudflare,
  Functional Software (Sentry), PostHog; también Google y Apple.
- **Cláusulas contractuales tipo**: Supabase (no figura adherido; las SCC van en su DPA).

Antes de publicar, comprueba que siguen activos en la lista oficial
(https://www.dataprivacyframework.gov/list): la adhesión caduca si no la renuevan.

## 13. Licencias de fotos y fuentes — ✅ revisado el 2026-11-19

- **Fuentes** (Instrument Sans, Newsreader, IBM Plex Mono, Caveat): SIL OFL 1.1, uso comercial
  permitido. **Iconos** Phosphor: MIT. Sus textos de licencia van en el bundle y se ven en
  Ajustes › Licencias de código abierto, junto con las de los paquetes.
- **Audio del lector**: Kokoro-82M, Apache-2.0. **Pitidos**: sintetizados por nosotros (D-058).
- **Fotos**: 416 de Pixabay (licencia con uso comercial, sin atribución) y 196 generadas con OpenAI
  (del usuario, uso comercial). Inventario completo en `content/LICENSES.md`.
- **Recomendación**: Pixabay no cubre las **marcas** que salgan en una foto. Sustituir las dos fotos de
  Pokémon GO (`b1-e10-a1`, `c1-e13-a2`); las de iPhone/Apple Watch (`b2-e17-a2`, `c1-e16-a3`,
  `c1-e28-b3`) y el concierto (`b1-e09-a1`) tienen riesgo bajo (uso incidental, sin logotipos en
  primer plano), pero conviene revisarlas a ojo.

## 14. Conservación de usuarios expulsados — ✅ resuelto el 2026-11-19 (D-065)

Se guarda solo el **hash del correo** (`public.banned_identities`), como ya se hacía con el examen de
prueba (`trial_claims`). Con él, el mismo correo no puede volver a registrarse (error `banned`, con
mensaje propio en la app). Lo explican la Política (§3 y §4, «Huella del correo electrónico») y los
Términos (10.2).

Uso: `select private.ban_user('<uuid>', '<motivo>');` guarda el hash, cierra los reportes abiertos
contra el usuario y borra la cuenta igual que un borrado voluntario. Para levantar una expulsión:
`delete from public.banned_identities where email_hash = private.email_hash('<correo>');`.

---

## Resumen de lo que ya está hecho

- Los dos documentos están redactados en español, con prosa propia (no formato de IA), y cubren LSSI,
  RGPD, LOPDGDD, condiciones de Apple, DSA, consumidores y desistimiento.
- La app los muestra en Ajustes y durante el registro (`LegalScreen`).
- **El registro ya obliga a aceptarlos**: la casilla del onboarding bloquea el alta hasta marcarla, y
  el servidor guarda la versión aceptada y la fecha (`profiles_private.terms_version` /
  `terms_accepted_at`, columnas `not null`).
- Solo hay documentos en español. Si publicas en mercados de habla inglesa, habrá que traducirlos (la
  app ya avisa al usuario de habla no española de que el texto legal está en español).
