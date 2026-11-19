# Formularios de App Store Connect y Google Play Console: respuestas

Rellenado el 2026-11-19 para el **lanzamiento gratuito** (D-067): sin suscripciones a la venta, sin
anuncios (AdMob no está integrado) y edad mínima **16** (D-066). Copia cada respuesta tal cual en
el formulario. Si se activan las suscripciones o los anuncios, revisa las filas marcadas con ⚠.

Datos que se repiten en los dos:

| Campo | Valor |
|---|---|
| Nombre | MirloTalk |
| Desarrollador / vendedor | Alfonso Esteban Meseguer García (persona física) |
| Categoría | Educación (secundaria: ninguna) |
| Precio | Gratis. Sin compras dentro de la app ⚠ |
| Contacto | `soporte@mirlotalk.app` (**crear antes**, ver ASPECTOS §2) |
| URL de la Política de privacidad | **Pendiente**: hace falta publicarla en una web (ver «Bloqueantes») |
| Paquete / Bundle ID | `com.speakingp2p.speaking_p2p` |

## Bloqueantes antes de enviar (no son del formulario, pero los pide)

1. **Correo de soporte que funcione** (ASPECTOS §2).
2. **URL pública** con la Política de privacidad y los Términos (las dos tiendas la exigen) y una
   **página para pedir el borrado de la cuenta sin la app** (Google la exige). Con el dominio de §2:
   publicar `privacidad.md` y `terminos.md` en Cloudflare Pages, más una página «Eliminar mi cuenta»
   que diga: «Desde la app: Ajustes › Eliminar cuenta. Sin la app: escribe a privacidad@… desde el
   correo de tu cuenta; la borramos en un plazo máximo de 30 días».
3. **Cuenta de prueba para los revisores** (ver el final de este documento).
4. **Build de release** con `--dart-define-from-file=env/dev.json` (o un `env/prod.json` con las mismas claves; sin `FEATURE_*`, así que
   suscripciones y práctica premium quedan ocultas) y con los interruptores de desarrollo del
   servidor apagados: `dev_instant_rooms` y `dev_session_skip`. **`assume_paid` se queda
   encendido**: es lo que hace que todo el mundo use la app gratis (D-020, D-067).

---

## App Store Connect

### Clasificación por edad (Age Rating)

| Pregunta | Respuesta |
|---|---|
| Violencia (dibujos, realista, prolongada, gráfica) | Ninguna |
| Contenido sexual o desnudos | Ninguno |
| Lenguaje soez o humor crudo | Ninguno |
| Alcohol, tabaco, drogas | Ninguno |
| Terror, temas para adultos o sugerentes | Ninguno |
| Juegos de azar simulados / con dinero real | No |
| Concursos | No |
| Temas médicos o de tratamiento | No |
| Acceso libre a la web | No |
| **Contenido generado por usuarios** | **Sí** (chat de texto y llamadas de voz) |
| **Mensajería y chat** | **Sí** |
| **Comunicación entre usuarios sin moderar en tiempo real** | **Sí** (voz) |
| Publicidad | No ⚠ (sí si se integra AdMob) |
| Controles parentales | No |
| Verificación de edad | Sí: el usuario declara su fecha de nacimiento y se bloquea a los menores de 16 |
| Clasificación final | Si el cuestionario da menos, elige **«16+»** manualmente (coincide con la edad mínima) |

### Privacidad de la app (App Privacy)

- **¿Recoges datos?** Sí. **¿Rastreo (tracking)?** No. Nada se usa para publicidad ni se cruza con
  datos de otras empresas. ⚠ Con AdMob personalizado: sí, y hace falta ATT.
- Todos los tipos de abajo: **vinculados a la identidad del usuario**, **no** usados para rastreo.

| Tipo de dato (Apple) | Qué es en MirloTalk | Finalidad que marcar |
|---|---|---|
| Información de contacto › Correo electrónico | Correo de la cuenta de Google/Apple | Funcionalidad de la app |
| Contenido del usuario › Fotos o vídeos | Foto de perfil (opcional) | Funcionalidad de la app |
| Contenido del usuario › Datos de audio | Grabación de la sesión (solo si los dos la activan) y voz en la llamada | Funcionalidad de la app |
| Contenido del usuario › Otro contenido del usuario | Mensajes del chat de la reunión, valoraciones, reportes | Funcionalidad de la app |
| Identificadores › ID de usuario | uuid interno de la cuenta | Funcionalidad de la app, Analítica |
| Uso › Interacción con el producto | Estadísticas de uso de PostHog (se pueden desactivar) | Analítica |
| Diagnóstico › Datos de fallos | Informes de Sentry | Funcionalidad de la app |
| Diagnóstico › Datos de rendimiento | Informes de Sentry | Funcionalidad de la app |
| Otros datos | Fecha de nacimiento (edad mínima) | Funcionalidad de la app |

No marcar: ubicación, contactos, salud, finanzas, compras ⚠ (marcar «Historial de compras» cuando
haya suscripciones), historial de navegación ni de búsqueda, información sensible, teléfono
(ya no se pide, D-065).

### Otras preguntas

| Pregunta | Respuesta |
|---|---|
| Cifrado (Export Compliance) | Solo cifrado estándar del sistema (HTTPS/TLS, WebRTC de LiveKit): **exento**. Ya va `ITSAppUsesNonExemptEncryption = NO` en el `Info.plist`, así que no se pregunta en cada build |
| Content Rights: ¿contiene contenido de terceros? | Sí, con derechos: fotos de Pixabay (licencia comercial) y voces Kokoro (Apache-2.0); inventario en `content/LICENSES.md` |
| Inicio de sesión | Google y Apple (guía 4.8 cumplida: está Sign in with Apple) |
| Eliminación de cuenta en la app | Sí: Ajustes › Eliminar cuenta (guía 5.1.1(v)) |
| Notas para la revisión | Ver el texto al final |

---

## Google Play Console

### Contenido de la aplicación

| Sección | Respuesta |
|---|---|
| Política de privacidad | URL pública (bloqueante 2) |
| Acceso a la aplicación | «Todas o algunas funciones están restringidas»: dar la cuenta de prueba |
| Anuncios | **No contiene anuncios** ⚠ |
| Público objetivo | Solo **16-17** y **18 o más**. **No** marcar ningún grupo menor de 13 (evita la Families Policy) |
| ¿Atrae a niños sin querer? | No: examen de inglés B1-C1 para estudiantes y adultos |
| Aplicación de noticias | No |
| Gobierno / Funciones financieras / Salud | No / Ninguna / No |
| Rastreo de contactos COVID | No |
| Clasificación de contenido (IARC) | Ver abajo |
| Seguridad de los datos | Ver abajo |
| Servicios en primer plano (Android 14) | Tipo **microphone**: «Mantiene el audio de la llamada del examen cuando el usuario sale de la app o bloquea la pantalla (sesión de examen por parejas en curso)». Google pide un **vídeo corto**: grábalo con una sesión en curso y la app en segundo plano |
| Permisos sensibles | Ninguno de la lista restringida (micrófono, red y Bluetooth no lo son) |

### Clasificación de contenido (cuestionario IARC)

- Categoría: **«Todas las demás aplicaciones»** (no es un juego). Correo de contacto: el de soporte.
- Violencia, miedo, sexualidad, lenguaje soez, sustancias, apuestas: **No** en todas.
- **¿Los usuarios pueden interactuar o intercambiar información?** **Sí** (chat y voz).
- ¿Comparte la ubicación del usuario con otros? **No**.
- ¿Permite comprar productos digitales? **No** ⚠.
- ¿Es un navegador o buscador web? **No**.
- Resultado esperado: PEGI 3-12 con el descriptor «Interacción entre usuarios». Si sale menos de
  16, no importa: la edad mínima la pone la app y el público objetivo (16+).

### Seguridad de los datos (Data safety)

Respuestas generales:
- ¿Recoge o comparte datos de usuario? **Sí**.
- ¿Todos los datos se cifran en tránsito? **Sí**.
- ¿Los usuarios pueden pedir que se eliminen sus datos? **Sí** (en la app y en la URL del bloqueante 2).
- «Compartir» en el sentido de Google: **No se comparte ningún dato**. Supabase, LiveKit,
  Cloudflare, Sentry y PostHog son proveedores que tratan datos por nuestra cuenta, y Google no lo
  considera compartir.

| Tipo (Google) | ¿Se recoge? | ¿Obligatorio? | Finalidades |
|---|---|---|---|
| Información personal › Dirección de correo | Sí | Obligatorio | Funcionalidad de la app, Gestión de la cuenta |
| Información personal › ID de usuario | Sí | Obligatorio | Funcionalidad de la app, Analíticas, Gestión de la cuenta |
| Información personal › Otra información (fecha de nacimiento) | Sí | Obligatorio | Funcionalidad de la app (edad mínima) |
| Fotos y vídeos › Fotos | Sí | Opcional | Funcionalidad de la app (foto de perfil) |
| Audio › Grabaciones de voz o sonido | Sí | Opcional (solo si los dos activan la grabación) | Funcionalidad de la app |
| Mensajes › Otros mensajes en la app | Sí | Obligatorio para usar el chat | Funcionalidad de la app |
| Actividad en la app › Interacciones con la app | Sí | **Opcional** (se desactiva en Ajustes) | Analíticas |
| Actividad en la app › Otro contenido generado por el usuario | Sí (valoraciones y reportes) | Opcional | Funcionalidad de la app, Seguridad |
| Info y rendimiento de la app › Registros de fallos | Sí | Obligatorio | Funcionalidad de la app (estabilidad) |
| Info y rendimiento de la app › Diagnósticos | Sí | Obligatorio | Funcionalidad de la app (estabilidad) |
| Dispositivo u otros IDs | Sí (identificador anónimo de PostHog antes de iniciar sesión) | Opcional | Analíticas |

¿Los datos se procesan de forma efímera? **No** para todos los de arriba (se guardan), salvo la voz
de la llamada sin grabación, que solo se retransmite y no se declara como recogida.

No recoger: ubicación, contactos, calendario, archivos, historial web, información financiera ⚠
(historial de compras cuando haya suscripciones), salud, teléfono, nombre real.

---

## Cuenta de prueba y notas para la revisión (las dos tiendas)

Crea **dos cuentas** de Google de prueba (los revisores no pueden usar la tuya), entra una vez con
cada una para completar el onboarding y deja la contraseña en el formulario. Texto para las notas:

> MirloTalk is a free app for practising English speaking exams in pairs over a voice call. A live
> session needs two people: you can sign in with the two test accounts on two devices, or try the
> full exam alone with "Practise with a simulated partner" on the Home tab (no second person needed).
> Account deletion: Settings › Delete account. Reporting and blocking: from the chat, the waiting
> room, the exam and the feedback screen. Users must be 16 or older.

Cuando lo tengas, apunta aquí las dos cuentas (solo el correo; la contraseña nunca en el repo).
