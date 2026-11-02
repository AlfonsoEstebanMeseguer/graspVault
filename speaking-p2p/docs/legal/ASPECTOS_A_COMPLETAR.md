# Términos y Privacidad: lo que falta antes de publicar

Los dos documentos legales (`apps/mobile/assets/legal/terminos.md` y `privacidad.md`)
están redactados y listos para enseñarse en la app. Esta nota recoge lo que **no puedo
decidir por ti** y lo que conviene revisar antes de subir la app a App Store y Google Play.

Las notas internas `[REVISAR]` que antes vivían dentro de los dos `.md` se han movido aquí:
la app ya no las muestra y los documentos quedan limpios. Los huecos que siguen en los textos
aparecen como `[por completar antes de publicar]`.

Versión de los documentos: **2026-11-02** (constante `termsVersion` en
`apps/mobile/lib/domain/account/account.dart`). Si cambias algo relevante, sube también esa fecha.

---

## 1. Datos del titular (bloqueante: sin esto no se puede publicar)

En los dos documentos hay que rellenar quién es el responsable legal:

- **Titular / Responsable**: nombre y apellidos (si eres autónomo) o razón social.
- **NIF / CIF**.
- **Domicilio**.
- **Datos registrales**, solo si es una sociedad.

Por qué es obligatorio:

- Apple muestra el nombre del vendedor en la ficha de la app.
- Google exige una dirección de contacto pública para las cuentas de organización.
- El artículo 10 de la LSSI obliga a identificar al titular de un servicio de la sociedad de la información.

No he inventado estos datos a propósito: una política de privacidad con un NIF falso es, en sí misma,
un defecto legal. Tienen que ser reales.

## 2. Correos de contacto

Los documentos usan dos direcciones:

- `soporte@mirlotalk.app` (Términos: soporte, alegaciones, contacto general).
- `privacidad@mirlotalk.app` (Privacidad: derechos RGPD, menores).

Hace falta **registrar el dominio `mirlotalk.app`** (o el que elijas) y **crear esos buzones**, o
cambiar las direcciones por las que vayas a usar. El RGPD obliga a atender los derechos en un mes,
así que alguien tiene que leer ese correo.

## 3. Edad mínima (la decisión más delicada)

Hoy la app permite registrarse **desde los 14 años** (lo valida la fecha de nacimiento declarada,
en el formulario y en el servidor). Los documentos están escritos con esa edad. **Es el punto con
más probabilidad de dar problemas en las tiendas.**

El riesgo: la app pone en contacto, por **llamada de voz en directo y sin moderación humana**, a
personas desconocidas que pueden ser adultos o menores. Es el motivo más habitual de rechazo en las
tiendas y el de mayor riesgo reputacional. Apple asigna la clasificación por edad según un
cuestionario; con comunicación libre entre usuarios es probable que salga **16+ o 18+**, lo que
choca con un mínimo de 14. En Google Play, declarar menores en el público objetivo activa requisitos
adicionales (Families Policy).

Además, el consentimiento digital de un menor varía por país de la UE (13-16 años; 16 en Alemania y
Países Bajos, 15 en Francia, 14 en España por el art. 7 LOPDGDD). Si distribuyes fuera de España,
el mínimo de 14 no vale en todos los países.

Opciones, de más a menos segura:

1. **Subir la edad mínima a 18 años.** Lo más simple y lo que menos problemas da en las tiendas.
   (Es, de hecho, la decisión que se tomó en el proyecto anterior del vault, ADR 0044, por el mismo
   motivo: salas y llamadas entre desconocidos.) Habría que cambiar la validación en el formulario y
   en el servidor, y ajustar la frase de los documentos.
2. **16 años y distribuir solo en la UE**, revisando la clasificación por edad.
3. **Mantener 14 solo en España**, con controles adicionales (no emparejar menores con adultos,
   moderación). Es la opción que más trabajo y más riesgo deja.

> Decídelo tú. Si quieres, cambio la edad a 18 en los dos caminos de validación y en los documentos.

## 4. Marcas (Cambridge)

Los documentos dejan claro que la app es independiente y no está afiliada a Cambridge, y que los
nombres de examen se usan solo de forma descriptiva. Conviene que un abogado de marcas confirme el
uso de «B1 Preliminary», «B2 First» y «C1 Advanced» en la ficha de las tiendas y en la app. La
práctica segura: usarlos solo descriptivamente («para preparar el B2 First»), sin logotipos ni la
tipografía de Cambridge.

## 5. Teléfono: minimizar o justificar

Hoy se pide y se guarda el teléfono, pero la app no lo usa para nada. Por el principio de
minimización (art. 5.1.c RGPD) hay que **eliminarlo del registro** o **explicar para qué sirve**
(por ejemplo, avisos por SMS). Es una pregunta típica en una inspección. Recomendación: quitarlo
mientras no tenga uso.

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

## 8. Moderación y Reglamento de Servicios Digitales (DSA)

Los Términos prometen revisar los reportes «en un plazo razonable». Falta decidir y, si quieres,
reflejar un plazo concreto (p. ej. 48 h) y **quién** los revisa. Hoy no hay panel de administración:
se revisan en la tabla `user_reports` directamente en la base de datos.

El DSA obliga a toda plataforma a tener un mecanismo de notificación (art. 16) y a motivar las
decisiones de moderación (art. 17). Las microempresas están exentas de parte de las obligaciones
(art. 19) pero **no de estas dos**. El texto actual ya las cubre; conviene un plazo y un proceso.

## 9. Analítica y errores (Sentry / PostHog)

Cuando se integren (pendiente, va al final):

- **Sentry**: basta el interés legítimo si no se envían datos identificativos.
- **PostHog**: si se usa con identificadores de usuario o para perfilado, hay que pedir
  consentimiento o configurarlo de forma anónima (sin IP, sin identificador persistente).
- Añadir ambos al apartado 5 de Privacidad.

## 10. Proveedores: regiones y contratos (DPA)

- Confirmar en el panel de **LiveKit Cloud** y **Cloudflare R2** la región donde se procesan y
  guardan los datos. Si se puede, elegir la **UE** (R2 permite jurisdicción UE).
- Firmar un **contrato de encargo del tratamiento (DPA)** con cada proveedor del apartado 5. La
  mayoría lo ofrece en sus condiciones.
- Si el correo de confirmación no lo envía Supabase, añadir el proveedor de email.
- Llevar el **registro de actividades de tratamiento** (art. 30 RGPD). No es obligatorio nombrar un
  Delegado de Protección de Datos (DPO) por el volumen y tipo de datos.

## 11. Re-aceptación cuando cambie la versión (no implementado)

La app guarda la versión aceptada (`profiles_private.terms_version`) pero **todavía no vuelve a
pedir la aceptación** cuando esa versión cambia. Si publicas un cambio relevante, hay que añadir esa
pantalla de re-aceptación. Mientras tanto, cambiar `termsVersion` solo afecta a los registros nuevos.

## 12. Transferencias internacionales

Algunos proveedores (LiveKit, Cloudflare) son de EE. UU. Las transferencias se amparan en el Marco
de Privacidad de Datos UE-EE. UU. (si el proveedor está adherido) o en cláusulas contractuales tipo.
Verificar la adhesión de cada uno antes de publicar.

## 13. Licencias de fotos y fuentes

Comprobar que todas las licencias de `content/LICENSES.md` y de `assets/fonts` **permiten el uso
comercial** en una app de pago. Ya hay una regla del proyecto (D-047) de usar solo fotos con licencia
comercial (Pixabay), pero conviene revisar el inventario completo.

## 14. Conservación de usuarios expulsados

Hoy, al eliminar la cuenta, los reportes en los que el usuario es el reportado se ponen a `null`. Si
quieres conservar información de un usuario expulsado (por ejemplo, para impedir que vuelva a
registrarse), hay que decidirlo y reflejarlo en el apartado 4 de Privacidad.

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
