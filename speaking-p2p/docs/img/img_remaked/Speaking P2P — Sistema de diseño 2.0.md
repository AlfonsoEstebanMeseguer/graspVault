# Speaking P2P — Sistema de diseño 2.0

Oct 24, 2026 · @Alfon
[IMPORTANTE]: Si necesitas pedirme algo (por ejemplo animaciones para la mascota O CUALQUIER ASPECTO QUE NO PUEDAS INCORPORAR TU SOLO SIN AYUDA DE OTRA HERRAMIENTA O IA, PREGUNTA OBLIGATORIAMENTE O PIDE AYUDA)
## 1. Diagnóstico del diseño actual

La lógica del examen está muy bien resuelta (turnos, reloj sincronizado, partes), pero la interfaz es Material oscuro por defecto: todo tiene borde, todo pesa lo mismo y no queda claro de un vistazo **quién habla y cuánto tiempo queda**, que es lo único que importa durante un examen.

| Problema | Dónde se ve | Por qué importa | Corrección |
| --- | --- | --- | --- |
| Todo es un rectángulo con borde (inputs, chips, botones secundarios) | Login, registro, agenda, perfil | Ruido visual; los bordes compiten con el contenido | Superficies rellenas sin borde; borde solo en foco o selección |
| Los candidatos A y B tienen el mismo color | Partes 1–4 | Hay que leer "Hablando" o "Silenciado" para saber de quién es el turno | Un color fijo por rol: A índigo, B mandarina |
| El reloj es una píldora blanca sin estados | Partes 1–4, feedback | Deslumbra en modo oscuro y no avisa cuando el tiempo se acaba | Anillo de progreso con estados: normal, últimos 10 s, tiempo agotado |
| La barra "Diriges el examen" ocupa \~20 % de la pantalla en todas las partes | Partes 1–4 | Tapa la pregunta ("…to help" queda cortado en la Parte 2) | Dock de cristal compacto; controles extra en un sheet "Más" |
| "Abandonar" y "Terminar llamada" con el mismo peso que la acción principal | Examen, feedback | Riesgo de pulsarlo por error en un momento de tensión | Abandonar como acción terciaria con confirmación |
| El botón principal "Buscar pareja" usa un icono de micrófono | Inicio | El micro sugiere "hablar ahora", no "buscar" | Icono de dos personas o de onda que se une |
| Fotos de la Parte 2 como placeholders | Parte 2 | No se puede evaluar cómo se verá la comparación | Fotos a pantalla con pinch-to-zoom y etiqueta A/B |
| El diagrama de la Parte 3 es una lista de chips sobre un fondo plano | Parte 3 | No parece la hoja del examen real; poca jerarquía | Mapa "dibujado a mano" con la pregunta central en tarjeta de papel |
| Enlaces de texto sin jerarquía ("Practicar con compañero simulado", "VIP simulado") | Inicio | Parecen opciones de depuración | Tarjeta secundaria "Practicar sin pareja" con explicación |

Errores y restos de desarrollo que no deben llegar a producción:

- En la sala de espera laura\_m aparece como **Candidato B**, pero en el examen se muestra como **Tú · A**.
- Botón "Crear sala ahora (debug)" visible en el chat de una reunión.
- Grabación titulada "C1 con Usuario eliminado"; mejor "C1 con un compañero".
- Texto provisional en Ajustes: "La gestión en la tienda llegará con los pagos".
- "28 días" en la grabación no dice si es antigüedad o días hasta borrarse.
- "Plan Estándar · Activa" debería concordar: "Activo".

## 2. Estilos de diseño para una app de examen

Una app de examen necesita foco, no espectáculo: **Minimalismo + Flat** dentro del examen, **Liquid Glass** solo en el dock de control y la navegación, **Bento** fuera del examen (inicio, progreso, perfil), **Hand-drawn** en el diagrama de la Parte 3 y un toque de **Skeumorfismo** en las tarjetas de pregunta, que imitan la hoja del examinador.

| Estilo | Uso en Speaking P2P | Motivo |
| --- | --- | --- |
| **Minimalismo** | Principio rector dentro del examen | El estudiante está bajo presión; solo deben verse turno, reloj y pregunta |
| **Flat Design** | Contenido, listas, chat, formularios | Legible y rápido de renderizar mientras corre el audio |
| **Liquid Glass** | Dock "Diriges el examen", tab bar, sheets | Flota sobre el contenido sin taparlo; es el idioma nativo de iOS 26 |
| **Glassmorfismo** | Fallback en Android y dispositivos antiguos | Misma jerarquía cuando no hay shader de refracción |
| **Bento Grid** | Inicio, progreso, perfil, resultados | Resume nivel, racha, exámenes y próxima reunión en una pantalla |
| **Hand-drawn** | Diagrama de la Parte 3, estados vacíos | Recuerda a la hoja de examen y a apuntes de clase; da calidez |
| **Skeumorfismo (ligero)** | Tarjeta de pregunta tipo "papel" en serif, fotos con marco | Ancla mental: "esto es el examen", distinto de la interfaz |
| **Claymorfismo** | Mascota, insignias de nivel, celebración final | Solo fuera del examen, para premiar la constancia |
| **Spatial UI** | Paso entre partes del examen | Transición de "tarjeta que se aparta" para marcar el cambio de parte |
| **Neumorfismo** | Descartado | Contraste insuficiente en botones críticos (pausa, siguiente) |
| **Brutalismo** | Descartado | Tensión visual añadida a un momento ya tenso |
| **Maximalismo** | Solo en la pantalla "Examen terminado" (2 s) | Celebrar el esfuerzo; nunca durante el examen |

Apple recomienda reservar el cristal para la capa de navegación y controles y mantener opaco el contenido; la librería `liquid_glass_widgets` para Flutter da el mismo consejo en su documentación.

## 3. Dirección elegida: «Turno y Reloj»

Speaking P2P 2.0 se diseña como **la sala de examen más tranquila posible**: penumbra azul tinta, una tarjeta de pregunta como de papel, y dos colores que dicen siempre de quién es el turno. Concepto en una frase: *de un vistazo, sabes si te toca y cuánto te queda*.

&#91;embedded content: Flujo de una sesión · 2 entradas, 4 partes, feedback\]

Cada fase del flujo tiene su propio tratamiento: fuera del examen (inicio, agenda, espera) la app es cálida y en bento; dentro del examen se vuelve sobria, con el reloj y el turno como únicos protagonistas; en el feedback vuelve la calidez.

Cinco principios:

1. **El turno se ve, no se lee.** Color de candidato (A índigo, B mandarina) + anillo de voz + micro cerrado atenuado al 40 %.
2. **El reloj avisa sin asustar.** Anillo que se vacía; ámbar en los últimos 10 s; nunca rojo parpadeante.
3. **La pregunta es papel.** Tarjeta clara en serif, como la hoja del examinador; la interfaz alrededor es oscura y discreta.
4. **Mismo examen en los dos móviles.** Cualquier cambio del líder (pausa, +1 min) se anuncia con un toast a los dos: "Laura ha añadido 1 minuto".
5. **Control proporcional al plan.** Estándar ve un dock mínimo (pausa); Pro despliega el dock completo; nada de controles deshabilitados a la vista.

Referentes: el modo Concentración de iOS y el temporizador del Reloj (anillo), Apple Podcasts (controles de reproducción en glass), Duolingo (mascota y rachas fuera de la lección), Notion Calendar (agenda limpia).

## 4. Color

Fondo azul tinta (más "estudio" y menos "noche" que el violeta de Grasp), un primario cobalto y, sobre todo, dos colores de candidato que se distinguen también para personas con daltonismo: **índigo** para A y **mandarina** para B (pareja azul/naranja, la más segura).

### 4.1 Tokens (tema oscuro)

| Token | Hex | Uso |
| --- | --- | --- |
| `bg.base` | #0B0E14 | Fondo |
| `bg.elevated` | #131722 | Tarjetas, celdas |
| `bg.raised` | #1B2030 | Inputs, chips, botones secundarios |
| `bg.overlay` | #252B3D | Pulsado, separadores |
| `text.primary` | #F2F4F8 | Texto principal |
| `text.secondary` | #A9B1C3 | Metadatos (≈ 8:1) |
| `text.tertiary` | #7D8598 | Placeholders (≈ 4.8:1) |
| `brand.cobalt.500` | #4C6FFF | Botón primario, foco, enlaces sobre claro |
| `brand.cobalt.300` | #9DB0FF | Enlaces e iconos activos sobre oscuro |
| `role.a` | #7C8CFF | Candidato A: borde, anillo de voz, etiqueta |
| `role.b` | #FF9B5E | Candidato B: borde, anillo de voz, etiqueta |
| `role.examiner` | #E8ECF5 | Examinador: orbe de voz y tarjeta de pregunta |
| `paper` | #F4F1EA | Fondo de la tarjeta de pregunta |
| `paper.ink` | #1C1F27 | Texto sobre papel (≈ 15:1) |
| `state.live` | #3DDC97 | Micro abierto, conectado, listo |
| `state.warn` | #FFC24B | Últimos 10 s, conexión inestable |
| `state.over` | #FF6E6E | Tiempo agotado, abandonar, eliminar cuenta |
| `tier.pro` | #E2B65C | Insignia Pro (oro apagado) |

### 4.2 Niveles

| Nivel | Color | Hex | Dónde |
| --- | --- | --- | --- |
| B1 Preliminary | Menta | #3CC8A4 | Selector de nivel, insignia, chip en agenda |
| B2 First | Cielo | #5BB8FF | Ídem |
| C1 Advanced | Magenta suave | #E07BC0 | Ídem |

El nivel se muestra siempre con texto ("C1") además del color.

### 4.3 Estados del reloj

| Estado | Condición | Aspecto |
| --- | --- | --- |
| Normal | > 10 s | Anillo `brand.cobalt.300`, número `text.primary` |
| Aviso | ≤ 10 s | Anillo y número `state.warn`, un toque háptico suave |
| Agotado | 0 s y el examinador aún no ha cortado | Número `state.over`, anillo lleno, texto "Tiempo" |
| Pausado | El líder ha pausado | Anillo discontinuo, icono de pausa, toast a los dos |

### 4.4 Tema claro

`bg.base` #F6F7FA, `bg.elevated` #FFFFFF, `text.primary` #121521, `brand.cobalt.500` #3657F0, `role.a` #4F5FE0, `role.b` #D9682A (oscurecidos para pasar AA sobre blanco). La tarjeta de pregunta usa entonces `bg.elevated` con borde `paper` en lugar de papel.

## 5. Tipografía, espaciado, radios y elevación

Tres familias, cada una con un papel: **Instrument Sans** para la interfaz, **Newsreader** (serif) solo para lo que dice el examinador y las preguntas, e **IBM Plex Mono** solo para los relojes. La serif separa visualmente "el examen" de "la app"; la mono evita que los dígitos bailen al contar.

| Estilo | Familia / peso | Tamaño / interlínea (pt) | Uso |
| --- | --- | --- | --- |
| Large Title | Instrument Sans 700 | 32 / 38 | Títulos de pantalla |
| Title 1 | Instrument Sans 700 | 24 / 30 | Nombre de parte ("Long turn") |
| Title 2 | Instrument Sans 600 | 20 / 26 | Secciones |
| Headline | Instrument Sans 600 | 17 / 22 | Nombres, botones |
| Body | Instrument Sans 400 | 16 / 22 | Texto general |
| Footnote | Instrument Sans 500 | 13 / 18 | Metadatos |
| Overline | Instrument Sans 600, +1 tracking, mayúsculas | 12 / 16 | "PARTE 2 DE 4" |
| Question | Newsreader 500 | 22 / 30 | Pregunta del examinador (tarjeta de papel) |
| Question small | Newsreader 500 italic | 17 / 24 | Instrucciones ("Compare the photographs…") |
| Timer | IBM Plex Mono 600 | 28 / 32 | Reloj de parte y de feedback |
| Timer XL | IBM Plex Mono 600 | 56 / 60 | Cuenta atrás de la sala de espera |

En Flutter: `google_fonts` o fuentes empaquetadas en `pubspec.yaml`; `FontFeature.tabularFigures()` en los relojes; respetar `MediaQuery.textScaler` hasta 200 %.

**Espaciado** (base 4): 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48. Margen de pantalla 20; padding de tarjeta 16/20; objetivos táctiles ≥ 48 (Material) y ≥ 44 (iOS).

**Radios**: 10 chips · 14 inputs y botones pequeños · 20 tarjetas · 28 sheets y dock · cápsula para botones principales. Radio interior = exterior − padding.

**Elevación**: 0 fondo · 1 `bg.elevated` · 2 `bg.raised` + sombra 0 8 24 rgba(0,0,0,.35) · 3 glass (dock, tab bar) · 4 sheet glass denso con fondo atenuado 40 %. La tarjeta de papel lleva sombra propia (0 12 30 rgba(0,0,0,.45)) para "despegarse" del fondo.

## 6. Iconografía, logo y materiales

Iconos de línea redondeados: **Phosphor** (`phosphor_flutter`, variantes Regular y Fill) en ambas plataformas, porque Flutter no tiene SF Symbols nativos y Phosphor es la librería más cercana en tono; trazo 1.75 sobre rejilla de 24, relleno para el estado activo.

| Función | Icono Phosphor | Nota |
| --- | --- | --- |
| Examen (tab) | `Exam` → mejor `Waveform` | La tab principal es "Practicar" |
| Agenda | `CalendarDots` | Punto de notificación si hay oferta nueva |
| Perfil | `UserCircle` | — |
| Ajustes | `GearSix` | — |
| Buscar pareja | `UsersThree` o icono propio de dos ondas | Sustituye al micrófono |
| Micro abierto / cerrado | `Microphone` / `MicrophoneSlash` | Siempre con color de rol |
| Examinador | `SpeakerHigh` + orbe | — |
| Pausa, anterior, siguiente, saltar parte | `Pause`, `SkipBack`, `SkipForward`, `FastForward` | En el dock Pro |
| Añadir tiempo | `Timer` + "+1:00" | Texto siempre visible |
| Líder | `Crown` (en `tier.pro`) | Junto al nombre de quien dirige |
| Grabación | `Record` / `Waveform` | — |
| Abandonar | `SignOut` | Solo en menú, nunca destacado |

### 6.1 Logo y nombre visual

El isotipo actual (onda en un cuadrado) es genérico. Propuesta: **dos bocadillos de diálogo, uno índigo (A) y otro mandarina (B), que se solapan formando una onda** en la intersección. Expresa "por parejas" y "hablar" a la vez y reutiliza los colores de rol. Icono de app en capas (fondo, A, B) para que iOS 26 genere sus variantes clara, oscura, tintada y transparente.

### 6.2 Materiales

- **Glass** (dock del líder, tab bar, sheets): `liquid_glass_widgets` con calidad *standard* en scroll y *premium* solo en superficies fijas; en Android sin Impeller, modo *minimal* (blur + saturación + borde especular).
- **Papel** (tarjeta de pregunta y fotos): `paper` #F4F1EA, grano 2 %, sombra larga, esquina 20. Es el único elemento claro en modo oscuro: dirige la mirada a la pregunta.
- **Tiza / hand-drawn** (Parte 3): líneas con ligera irregularidad (`perfect_freehand` o `CustomPainter` con ruido), chips de opciones como notas adhesivas pequeñas.
- **Clay** (fuera del examen): mascota, insignias de nivel, medalla de examen completado.

## 7. Componentes y patrones por pantalla

El examen se construye con cinco piezas que se repiten en las cuatro partes: barra de progreso, cabecera con reloj, tira de candidatos, tarjeta de papel y dock del líder. Si esas cinco están bien, todo el examen está bien.

### 7.1 Componentes del examen

| Componente | Especificación |
| --- | --- |
| Progreso de partes | 4 segmentos de 4 px, radio 2; completado `brand.cobalt.300`, actual con relleno que avanza con el reloj, futuros `bg.overlay` |
| Cabecera | Overline "PARTE 2 DE 4" + Title 1 con el nombre en inglés; reloj a la derecha |
| Reloj de anillo | Anillo de 56 px, trazo 4, número Plex Mono 17 dentro; estados de la sección 4.3. Tocar = ver tiempo total de la parte |
| Tira de candidatos | Dos píldoras de 64 de alto con avatar, nombre y estado de micro. Quien habla: borde 2 px del color de su rol + anillo de voz; el silenciado al 45 % de opacidad. En las partes de turno individual, la persona activa ocupa 2/3 del ancho |
| Orbe del examinador | Círculo de 40 con onda animada mientras suena el audio; texto "Examinador" |
| Tarjeta de papel | Fondo `paper`, texto Newsreader 22, botón "Ocultar texto" como icono de ojo arriba a la derecha; con texto oculto queda una onda que sigue el audio |
| Chip de turno | "Te toca a ti" en `role.a`/`role.b` con icono de micro; aparece con un pequeño rebote y vibración ligera |
| Dock del líder (Pro) | Cápsula glass flotante de 64 de alto: Anterior · Pausa (grande) · Siguiente · Más. "Sig. parte", "± tiempo", "Cambiar examen" y "Ceder control" viven en el sheet "Más" |
| Dock Estándar | Solo Pausa + indicador de micro; sin botones deshabilitados |
| Estado de micro | Pastilla inferior izquierda: punto verde + "Tu micro está abierto"; gris + "Escuchando" cuando el servidor lo cierra |
| Abandonar | Dentro del menú "Más" o del botón de cerrar, con diálogo de confirmación |

### 7.2 Pantalla por pantalla

| Pantalla | Patrón | Cambios clave |
| --- | --- | --- |
| Bienvenida / login | Hero + formulario | Ilustración A–B con la mascota; selector de nivel como segmentado; Sign in with Apple / Google; inputs rellenos sin borde |
| Onboarding (3 pasos) | Un dato por paso | Usuario con validación en vivo y sugerencias; idiomas como chips con bandera textual (ES, EN); nivel objetivo y fecha del examen real (para la cuenta atrás) |
| Inicio | Bento | Tile grande "Buscar pareja" (gente buscando ahora en tu nivel), tile "Próxima reunión", tile "Practicar solo", racha semanal, último examen |
| Buscando pareja | Pantalla de espera | Anillos concéntricos que "buscan"; contador; consejo del examen en tarjeta de papel; "Cancelar" terciario |
| Agenda | Lista con segmentos | Segmented control Chats / Reuniones / Mi agenda; ofertas como tarjetas con nivel en color y franja horaria; "Crear reunión" como FAB glass |
| Chat de reunión | Mensajería | Tarjeta de propuesta fija arriba con estado de confirmación de cada uno (dos casillas A/B) |
| Sala de espera | Lobby | Cuenta atrás XL; tarjetas de los dos con rol asignado (A/B) y estado "Listo"; checklist: material descargado, grabación (los dos), micrófono probado; botón "Estoy listo" |
| Parte 1 | Entrevista | Candidato activo grande; pregunta en papel; chip "Te toca" |
| Parte 2 | Fotos | Dos fotos en carrusel con indicador 1/2 y zoom; pregunta debajo; el compañero ve "Escuchando a Laura · 0:42" |
| Parte 3 | Diagrama | Mapa hand-drawn con la pregunta central en papel; fases "Discusión · 2 min" → "Decisión · 1 min" como stepper |
| Parte 4 | Discusión | Los dos activos; pregunta en papel; contador de preguntas restantes |
| Feedback | Llamada libre | Reloj de feedback; tarjetas de ideas deslizables; botón "Terminar" normal + "+1 min" para Pro |
| Resumen (nuevo) | Bento | Duración, partes completadas, grabación si la hubo, "¿Repetir con la misma pareja?", racha |
| Perfil | Bento | Nivel objetivo, exámenes hechos, horas de speaking, insignias, grabaciones con caducidad explícita ("se borra en 28 días") |
| Ajustes | Lista agrupada | Apariencia e idioma como segmentados; suscripción con comparativa Estándar / Pro |

## 8. Motion, animaciones y háptica

Dentro del examen, el movimiento solo comunica estado (turno, tiempo, cambio de parte); fuera del examen puede celebrar. Todo respeta "Reducir movimiento" (`MediaQuery.disableAnimations`).

| Token | Valor (Flutter) | Uso |
| --- | --- | --- |
| `motion.snappy` | `SpringDescription(mass: 1, stiffness: 420, damping: 32)` | Botones, chips, dock |
| `motion.smooth` | `Curves.easeOutCubic`, 280 ms | Sheets, cambio de pantalla |
| `motion.part` | 600 ms | Transición entre partes |
| `motion.voice` | Escala 1 → 1.12 según nivel de audio, 60 fps | Anillo de voz |

Microinteracciones clave:

1. **Anillo de voz** del color del rol, alimentado por el nivel de audio de LiveKit (`AudioLevel`), suavizado a 100 ms.
2. **Cambio de turno**: la píldora del candidato que entra crece a 2/3 y la del que sale se atenúa; chip "Te toca a ti" con rebote; háptica `selectionClick`.
3. **Cambio de parte**: la tarjeta de papel se desliza hacia la izquierda y entra la siguiente (efecto de "pasar página"); el segmento de progreso se completa.
4. **Reloj**: el anillo se vacía de forma continua; a los 10 s pasa a ámbar con un pulso único (no parpadeo) y `HapticFeedback.lightImpact`.
5. **Orbe del examinador**: onda de 5 barras mientras suena el audio; al terminar se encoge y el micro del candidato se "enciende".
6. **Buscando pareja**: anillos concéntricos que se expanden cada 2 s; al encontrar pareja, los dos avatares A y B se acercan y se solapan (logo vivo).
7. **Sala de espera**: casilla "Listo" que se rellena con check dibujado; cuando los dos están listos, la cuenta atrás salta a 5 s.
8. **Examen terminado**: confeti en colores A y B durante 2 s y la mascota celebrando (Rive).
9. **Toast sincronizado**: cuando el líder pausa o añade tiempo, toast glass en los dos móviles con el nombre de quien lo hizo.
10. **Skeletons** con brillo lento en agenda y grabaciones.

Háptica (servicio `HapticFeedback` de Flutter): `selectionClick` al cambiar de turno o de segmento, `lightImpact` a 10 s del final, `mediumImpact` al pausar/reanudar, `heavyImpact` solo al confirmar "Abandonar".

Herramientas: `flutter_animate` (secuencias declarativas), `rive` (mascota con state machine), `lottie` (confeti), `CustomPainter` (anillo del reloj y diagrama), animaciones implícitas de Flutter para todo lo demás.

## 9. Mascota e incorporaciones nuevas

La mascota es **Pico**, un loro clay pequeño: los loros repiten palabras, que es justo lo que hace quien practica speaking, y no se confunde con el búho de Duolingo. Pico vive fuera del examen; dentro, el examinador es un orbe de voz neutro para no restar seriedad.

### 9.1 Pico

- **Forma**: cuerpo redondo, alas cortas; plumaje índigo con la cola mandarina (los dos colores de rol). Clay con brillo suave.
- **Técnica**: Rive con state machine (`idle`, `saluda`, `busca`, `escucha`, `celebra`, `dormido`) y entrada `level` (B1/B2/C1) que cambia un pequeño accesorio: gorra, pajarita, birrete.
- **Dónde**: bienvenida, buscando pareja (busca con un catalejo), sala de espera (calienta la voz), examen terminado (celebra), estados vacíos de agenda y grabaciones.
- **Dónde no**: nunca durante las partes 1–4, ni en pagos, ni al borrar la cuenta.

### 9.2 Incorporaciones

| # | Incorporación | Qué aporta | Esfuerzo |
| --- | --- | --- | --- |
| 1 | **"12 personas buscando en C1 ahora"** en el tile de inicio (Supabase Realtime presence) | Confianza en que encontrarás pareja | Bajo |
| 2 | **Calentamiento de micro** en la sala de espera: medidor de nivel + "Di tu nombre" | Evita el "¿me oyes?" al empezar la Parte 1 | Bajo |
| 3 | **Live Activity / Dynamic Island** (iOS) y notificación en curso (Android) con parte y reloj | Seguir el examen con la pantalla bloqueada | Medio |
| 4 | **Rúbrica de feedback guiada** con los 4 criterios de evaluación oral de Cambridge (gramática y vocabulario, gestión del discurso, pronunciación, comunicación interactiva), puntuación privada 1–5 al compañero | Feedback concreto en lugar de "muy bien" | Medio |
| 5 | **Resumen del examen** en bento al terminar | Cierre claro y motivo para repetir | Bajo |
| 6 | **Cuenta atrás al examen real** (fecha opcional en el onboarding) | Motivación y plan de práctica | Bajo |
| 7 | **Racha semanal** (no diaria): "3 exámenes esta semana" | Constancia realista sin presión diaria | Bajo |
| 8 | **Frases útiles por parte** en un sheet opcional de la sala de espera | Preparación previa (no durante el examen) | Bajo |
| 9 | **Fiabilidad de la pareja** (puntualidad, exámenes completados) en la tarjeta de oferta | Menos plantones en la agenda | Medio |
| 10 | **"Repetir con la misma pareja"** y lista de compañeros habituales | Retención | Bajo |
| 11 | **Grabación con marcadores por parte** cuando llegue la reproducción | Ir directo a la Parte 2 para escucharse | Medio |
| 12 | **Indicador de calidad de conexión** (LiveKit `ConnectionQuality`) junto al micro | Explica cortes sin culpar al compañero | Bajo |
| 13 | **Añadir reunión al calendario** (.ics / `add_2_calendar`) | Menos olvidos | Bajo |
| 14 | **Widget de inicio** con la próxima reunión y botón "Unirme" | Acceso directo | Medio |

Se evita a propósito: puntuaciones automáticas que parezcan notas oficiales, rankings públicos entre estudiantes y cualquier control del líder que no se anuncie al otro candidato.

## 10. iOS y Android con Flutter

Flutter dibuja sus propios widgets, así que el aspecto "nativo" hay que decidirlo: una sola marca para las dos plataformas, con comportamientos adaptativos donde el usuario los espera (gestos, hojas, selectores, háptica).

| Patrón | iOS 26 | Android | En Flutter |
| --- | --- | --- | --- |
| Navegación | Tab bar glass flotante que se minimiza al hacer scroll | NavigationBar M3 con píldora | `GlassTabBar.minimizable` en iOS; `NavigationBar` en Android |
| Volver | Gesto desde el borde | Predictive back | `CupertinoPageRoute` / `PredictiveBackPageTransitionsBuilder` |
| Hojas | Sheet con detents | Bottom sheet M3 | `showCupertinoSheet` / `showModalBottomSheet` según plataforma |
| Selector de fecha y hora | Rueda compacta | Material picker | `.adaptive` constructors y `CupertinoDatePicker` |
| Segmentados | Segmented control | Segmented buttons | `CupertinoSlidingSegmentedControl` / `SegmentedButton` |
| Interruptores | Switch iOS | Switch M3 | `Switch.adaptive` |
| Diálogos | Alert iOS | Dialog M3 | `showAdaptiveDialog` |
| Audio en segundo plano | Modo background audio + Live Activity | Foreground service con notificación | LiveKit + `live_activities` / notificación en curso |
| Login | Sign in with Apple + Passkeys | Credential Manager | `sign_in_with_apple`, Supabase Auth |
| Pantalla completa | Safe areas | Edge-to-edge obligatorio | `SafeArea` + `SystemUiMode.edgeToEdge` |
| Glass | Shader premium (Impeller/Metal) | Standard o minimal según GPU | `liquid_glass_widgets` con `GlassAdaptiveScope` |

Regla de rendimiento: durante el examen hay audio en tiempo real; el glass del dock va en calidad *standard*, el anillo de voz se limita a 60 fps y nada de blur detrás de listas que hacen scroll.

## 11. Accesibilidad, nombre y aspectos legales

### 11.1 Accesibilidad

- Contraste AA en ambos temas; los colores de rol pasan 4.5:1 sobre `bg.elevated` y nunca son la única señal (siempre "A"/"B" y el estado del micro en texto).
- Lectores de pantalla (`Semantics`): "Te toca hablar, quedan 40 segundos"; anuncio automático al cambiar de turno o de parte (`SemanticsService.announce`).
- Texto de la pregunta siempre disponible (no solo audio) para personas con hipoacusia; tamaño ajustable en la tarjeta de papel.
- Reducir movimiento: anillo de voz sustituido por un borde fijo; transiciones de parte por fundido.
- Alto contraste: glass sustituido por superficie opaca (`liquid_glass_widgets` lo hace con su modo de alto contraste en iOS).

### 11.2 Nombre

"Speaking P2P" describe la tecnología, no el beneficio, y "P2P" suena técnico. Ideas a validar (comprobar disponibilidad de marca y dominio): **Turno**, **Pareja Speaking**, **SpeakDuo**, **Tandem Exam**. En este documento se mantiene el nombre actual.

### 11.3 Marca Cambridge

"Cambridge", "B1 Preliminary", "B2 First" y "C1 Advanced" son nombres de exámenes de Cambridge University Press & Assessment. Conviene revisarlo con un abogado: lo habitual es no usar su logotipo ni su tipografía, describir los exámenes como formato "similar a" o "para preparar", y añadir un aviso visible de que la app no está afiliada ni respaldada por Cambridge. No soy abogado; esto es un punto a verificar, no una opinión legal.

## 12. Skills de Claude Code, paquetes Flutter y plan

Para Flutter, la base es el plugin oficial de Flutter/Dart para Claude Code (skills + servidor MCP de Dart), complementado con una skill de criterio visual y otra de iOS 26. Comprueba versiones antes de instalar.

### 12.1 Skills

| Skill | Para qué | Instalación |
| --- | --- | --- |
| **dart-flutter** (oficial) | Layouts adaptativos, routing, serialización, análisis estático y tests, con el MCP de Dart | `claude plugin marketplace add flutter/agent-plugins` y `claude plugin install dart-flutter@dart-flutter` |
| **frontend-design** (Anthropic) | Fijar dirección estética antes de codificar; evita el "Material oscuro por defecto" | Repo `anthropics/skills` |
| **ui-ux-pro-max** | Estilos, paletas y tipografías con guía específica para Flutter | `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` y `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill` |
| **mobile-design-ios** | Reglas de Liquid Glass e iOS 26 para la variante iOS | Repo `ivan-magda/mobile-design-skills` |
| **Supabase agent skills** | Buenas prácticas de seguridad y desarrollo con Supabase (Realtime, Auth, Edge Functions) | `npx skills add supabase/agent-skills` |
| **Interface Design** (plugin) | Recordar decisiones de UI entre sesiones | Lista *awesome-ai-tools-for-ui* |

### 12.2 Paquetes Flutter

| Paquete | Uso |
| --- | --- |
| `liquid_glass_widgets` | Tab bar, dock, sheets y botones de cristal con fallbacks por GPU (requiere Flutter ≥ 3.41) |
| `flutter_animate` | Microinteracciones declarativas |
| `rive` | Mascota Pico y orbe del examinador |
| `lottie` | Confeti de fin de examen |
| `phosphor_flutter` | Iconos |
| `google_fonts` | Instrument Sans, Newsreader, IBM Plex Mono |
| `livekit_client` | Audio, nivel de voz, calidad de conexión |
| `live_activities` | Live Activity / Dynamic Island |
| `add_2_calendar` | Añadir reuniones al calendario |

### 12.3 Preparar el repo

1. `DESIGN.md` en la raíz con las secciones 3–11 (exporta este doc a Markdown).
2. `lib/theme/tokens.dart` con `ThemeExtension`s: `AppColors` (incluidos `roleA`, `roleB`, `paper`), `AppType`, `AppSpacing`, `AppRadii`, `AppMotion`. Ningún `Color(0x…)` fuera de ese archivo.
3. `lib/ui/exam/` con los cinco componentes del examen (sección 7.1) como widgets aislados y una pantalla de catálogo para probarlos.
4. En `CLAUDE.md`: "Lee DESIGN.md antes de tocar UI. Usa solo tokens. Glass solo en dock, tab bar y sheets. Nunca cambies la lógica de turnos o reloj al rediseñar."

### 12.4 Plan por fases

| Fase | Contenido | Resultado verificable |
| --- | --- | --- |
| 1. Cimientos | Tokens, fuentes, temas, componentes base; corregir errores de la sección 1 | Catálogo de componentes en claro y oscuro |
| 2. Examen | Progreso, reloj de anillo, tira de candidatos A/B, tarjeta de papel, dock Pro/Estándar | Las 4 partes con la misma pareja en dos móviles, sin desincronizar |
| 3. Antes del examen | Inicio bento, buscando pareja, sala de espera con calentamiento de micro | Del inicio al examen en menos de 3 toques |
| 4. Después | Feedback con rúbrica, resumen, grabaciones | Feedback completado en ≥ 50 % de sesiones (métrica a medir) |
| 5. Agenda y social | Ofertas, chat con tarjeta de propuesta, fiabilidad de pareja, calendario | Reunión creada y confirmada sin salir del chat |
| 6. Pulido | Pico en Rive, Live Activity, accesibilidad, háptica | 0 incidencias AA; prueba con lector de pantalla |

Prompt sugerido por pantalla: *"Lee DESIGN.md y el mockup de \[pantalla\]. Reconstruye solo la UI con los tokens de lib/theme/tokens.dart y los componentes de lib/ui/exam/, sin tocar la lógica de Supabase ni LiveKit. Añade las microinteracciones de la sección 8 que correspondan y enséñame el diff."*

## Fuentes

- [Agent skills for Flutter and Dart — docs.flutter.dev](https://docs.flutter.dev/ai/agent-skills.md)
- [liquid\_glass\_widgets — pub.dev](https://pub.dev/documentation/liquid_glass_widgets/1.4.4/)
- [iOS 26 and Liquid Glass — Firefox Acorn](https://acorn.firefox.com/latest/mobile/patterns/i-os-26-and-liquid-glass-w2oH48nk)
- [Liquid Glass in Swift: Official Best Practices — DEV](https://dev.to/diskcleankit/liquid-glass-in-swift-official-best-practices-for-ios-26-macos-tahoe-1coo)
- [mobile-design-ios skill — Tessl](https://tessl.io/registry/skills/github/ivan-magda/mobile-design-skills/mobile-design-ios)
- [Claude Code skills directory — DEV](https://dev.to/shreyvijayvargiya/claude-code-skills-directory-every-official-skill-repo-i-use-from-react-to-rust-42e5)
- [Awesome AI Tools for UI — GitHub](https://github.com/maxbogo/awesome-ai-tools-for-ui)
- [Web Design Trends 2026 — The Plus Addons](https://theplusaddons.com/blog/web-design-trends-2026/)
- [Duolingo: world character visemes con Rive](https://blog.duolingo.com/world-character-visemes)
