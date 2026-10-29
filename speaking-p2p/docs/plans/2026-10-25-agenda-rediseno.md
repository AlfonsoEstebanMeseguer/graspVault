# Agenda: recorrido, rediseño y revisión de la lógica

> 2026-10-25 · Tareas 1 y 2 del prompt de sesión. **Nada de esto está implementado**: espera el visto bueno de Alfonso.

## 1. Recorrido como usuario nuevo: dónde se pierde

Entro en la pestaña Agenda por primera vez, sin reuniones:

1. **Tres pestañas que son la misma cosa en tres momentos.** Una reunión empieza en «Ofertas» (como oferta), pasa a «Chats» cuando alguien la acepta y llega a «Mi agenda» solo cuando la confirman los dos. Para saber qué tengo pendiente debo abrir las tres pestañas.
2. **Cinco palabras para la misma idea:** «Ofertas», «Ofrecer horario», «Crear reunión» (título de la hoja), «Publicar oferta» y «Proponer y chatear». Nadie explica que *oferta → alguien elige hora → chat → los dos confirman → reunión*.
3. **Lo que exige mi acción queda escondido.** Si mi compañero ya confirmó y falta yo, solo lo dice una línea de 12 px en la lista de Chats. No hay un aviso «te toca confirmar».
4. **«2 interesados» no lleva a ningún sitio.** En «Mis ofertas» no se puede tocar: el creador tiene que adivinar qué chats de la lista son de esa oferta.
5. **Los filtros van antes que el contenido.** «● C1 Advanced ⌄», «+ Incluir B2» y «Cualquier día ⌄» ocupan dos filas antes de la primera oferta, y «+ Incluir B2» no se entiende sin pensarlo.
6. **El tablón vacío es un callejón sin salida:** «No hay ofertas» sin botón para proponer la mía. El botón «Ofrecer horario» flota abajo, lejos, y en la captura de pantalla de `docs/screenshots/02-agenda-y-cuenta.png` ni siquiera aparece (hay que comprobarlo en el móvil, puede quedar bajo la barra de pestañas).
7. **Aceptar exige dos pasos que parecen uno.** Elijo hora en la franja de otro, «Proponer y chatear», y luego **también** tengo que pulsar «Confirmar» en el chat. ¿No acabo de decir que me va bien?
8. **En la tarjeta del chat, «Cancelar» pesa lo mismo que «Confirmar».** Tres botones del mismo tamaño en un momento de decisión.
9. **El estado final es ambiguo.** «Cerrada», «Cancelada», «Caducada» y «No disponible» significan para el usuario lo mismo: esa reunión ya no va.
10. **«Mi agenda» muestra 7 días** pero las reuniones confirmadas y las pendientes viven separadas, así que el calendario no refleja lo que tengo «casi cerrado».

## 2. Rediseño propuesto (solo interfaz, con el backend actual)

**Idea:** la Agenda pasa de «tres listas por estado» a **«mis exámenes» + «buscar horario»**. Cada reunión es **una tarjeta** que muestra su estado y lleva a su chat; el chat deja de ser una pestaña.

### 2.1 Pestaña «Mis exámenes» (por defecto si tengo algo; si no, «Buscar horario»)

```
 Agenda                                  [＋ Proponer]
 ┌─────────────────────┬─────────────────────┐
 │    Mis exámenes · 1 │   Buscar horario    │
 └─────────────────────┴─────────────────────┘

 TE TOCA                                         ← solo si hay algo
 ┌──────────────────────────────────────────────┐
 │ (M) marta.eng                       [C1]     │
 │ Mañana · 18:30                               │
 │ ✓ marta.eng   ○ Tú                           │
 │ [        Confirmar        ]   💬 2           │
 └──────────────────────────────────────────────┘

 PRÓXIMOS
 ┌──────────────────────────────────────────────┐
 │ HOY   │ C1 con sergi_cae            ✓✓       │
 │ 19:00 │ Empieza en 4 min    [Entrar a la sala]│
 └──────────────────────────────────────────────┘
 ┌──────────────────────────────────────────────┐
 │ JUE 17│ B2 con ana_p              Esperando a │
 │ 10:30 │ ana_p · 💬                            │
 └──────────────────────────────────────────────┘

 MIS PROPUESTAS · 1 DE 2
 ┌──────────────────────────────────────────────┐
 │ Mañana · 17:00–20:00 · C1          Retirar   │
 │ 2 personas han elegido hora:                 │
 │  (L) laura_m · 17:30 ›   (P) pau · 19:00 ›   │ ← cada una abre su chat
 └──────────────────────────────────────────────┘

 ▸ Anteriores (3)                                ← plegado: canceladas,
                                                   hechas, no disponibles
```

- «Te toca» agrupa lo que espera mi acción (confirmar). Lo demás va por fecha.
- Una tarjeta = una reunión pendiente o confirmada. Tocarla abre el chat. El número junto a 💬 son los mensajes sin leer *(si no se quiere contar sin leer, solo el icono)*.
- «Mis propuestas» enseña **quién** ha elegido hora y a qué hora, y cada nombre abre su chat (resuelve el punto 4).
- Estados finales unificados como «Ya no va» (con el motivo pequeño debajo) dentro de «Anteriores».
- Vacío: Pico dormido + «Aún no tienes exámenes agendados» + botones «Buscar horario» y «Proponer el mío».

### 2.2 Pestaña «Buscar horario»

```
 [Hoy] [Mañana] [Jue 17] [Vie 18] [Sáb 19] ...   ← tira de días, desliza
 Nivel: [● C1 ⌄]     □ Ver también B2

 HOY
 ┌──────────────────────────────────────────────┐
 │ (S) sergi_cae                    [C1]   ⋯    │
 │ Habla ES · CA · EN                           │
 │ Libre de 18:00 a 21:00                       │
 │ [18:00] [18:30] [19:00̶] [19:30] [20:00] [20:30]│ ← huecos tocables
 └──────────────────────────────────────────────┘

 (vacío) Nadie ha propuesto horario para este día.
         [＋ Proponer el mío]
```

- Los huecos van **dentro de la tarjeta**: tocar «18:30» abre una hoja corta de confirmación («Examen C1 con sergi_cae · Hoy 18:30 · [Pedir este hueco]»). Un paso menos que hoy.
- Los huecos que chocan con mis reuniones salen tachados (como el «Ocupado» actual).
- La tira de días sustituye al desplegable «Cualquier día»; el filtro de nivel adyacente pasa a una casilla con texto claro.

### 2.3 Chat de una reunión

```
 ←  (M) marta.eng                             ⚑
     Habla español, inglés
 ┌──────────────────────────────────────────────┐
 │ VIE 16 │ Examen C1 · Mañana 18:30            │
 │ 18:30  │ ●───────●───────○                    │
 │        │ Propuesta  Marta ✓  Tú               │
 │ [          Confirmar          ]              │
 │  Cambiar hora · Cancelar                     │ ← texto secundario
 └──────────────────────────────────────────────┘
       Propusiste Mañana · 18:00
 ¿Te va bien a las 18:30?
       marta.eng cambió la hora a 18:30
 [Llego 5 min tarde] [¿Otra hora?] [¡Hecho!]      ← respuestas rápidas
 [ Mensaje…                              ] (➤)
```

- Una sola acción principal según el estado (Confirmar → Esperando → Entrar a la sala). «Cambiar hora» y «Cancelar» bajan a enlaces.
- Respuestas rápidas sobre la organización: invitan a usar el chat para lo justo (no requieren backend).

### 2.4 «Proponer horario» (hoja)

Mismo formulario, con un título único y una frase que explica el sistema: *«Elige cuándo estás libre. Otros estudiantes de tu nivel elegirán una hora dentro de tu franja y os escribiréis para cerrarla.»* El botón pasa de flotante a la cabecera («＋ Proponer»), siempre visible.

### 2.5 Vocabulario único

| Hoy | Propuesta |
|---|---|
| Ofertas / Ofrecer horario / Crear reunión / Publicar oferta | **Proponer horario** (acción) y **propuesta** (objeto) |
| Elegir hora / Proponer y chatear | **Pedir este hueco** |
| Chats / Mi agenda | **Mis exámenes** |
| Cerrada / Cancelada / Caducada / No disponible | **Ya no va** + motivo |

### 2.6 Qué toca en el código

`agenda_screen.dart` (dos pestañas, tarjetas, secciones), `chat_screen.dart` (tarjeta con pasos y una acción), `accept_offer_sheet.dart` (pasa a hoja de confirmación de un hueco), `create_offer_sheet.dart` (textos), ARB ES/EN, `test/features/agenda_flow_test.dart` y las capturas. Sin cambios en `agenda_repository.dart` ni en Supabase. La lista «Te toca»/«Próximos» se monta con `chatsProvider` (ya trae la reunión de cada chat) y `myOffersProvider`; para «quién ha elegido hora» en mis propuestas se cruzan los chats por `meeting.offerId`.

## 3. Revisión de la lógica (Tarea 2)

Objetivo del producto: **quedar y hablar lo justo para organizar un examen**, **repetir fácilmente con compañeros habituales**, y **no** ser una red social.

### 3.1 Problemas concretos

| # | Problema | Dónde | Efecto |
|---|---|---|---|
| L1 | **El chat sigue abierto para siempre.** `chat_messages_send` solo comprueba que los dos existan, no el estado de la reunión. Tras «cancelada», «cerrada» o «hecha» se puede seguir escribiendo indefinidamente | Política RLS del esquema base | Es mensajería libre sin reunión detrás: justo lo que no queremos |
| L2 | **Varios aceptantes por oferta.** Cada uno abre un chat, negocia, y todos menos uno reciben «ya no está disponible» | `svc_offer_accept`, `svc_meeting_confirm` | Esfuerzo perdido, chats muertos acumulados y un creador que gestiona N conversaciones |
| L3 | **Confirmación doble redundante.** Quien acepta ya ha elegido una hora dentro de la franja que el creador declaró libre, pero aun así los dos deben pulsar «Confirmar» | `meetings.*_confirmed` | Un paso de más; reuniones que caducan en «pendiente» porque alguien no volvió |
| L4 | **«Modificar» reinicia las dos confirmaciones** | `svc_meeting_modify` | Ping-pong: cada cambio exige dos toques nuevos |
| L5 | **No hay forma de repetir con alguien.** Para volver a examinarte con la misma persona tenéis que coincidir por casualidad en el tablón | — | La retención depende del azar; no hay «compañeros habituales» |
| L6 | **Rejillas distintas.** Aceptar usa huecos de 30 min; modificar acepta cualquier múltiplo de 5 min (`valid_slot`) | `svc_meeting_modify` vs `AgendaRules.slots` | Reuniones a las 18:35 que no encajan con la rejilla del resto |
| L7 | **El aviso de 10 min no llega** (push sin Firebase) y no hay alternativa | `notification_outbox` | Ausencias; la cortesía de 10 min no basta si nadie se acuerda |
| L8 | **Estados finales que el usuario no distingue** (`closed`, `cancelled`, `expired` en ofertas, `meeting_expired`) | Varias | Ruido, sin valor para el usuario |
| L9 | **Los chats viejos no se borran nunca** | — | Datos personales guardados sin necesidad (minimización, RGPD) |
| L10 | Ausencias registradas (`attendance`) sin ningún efecto | `svc_cron_agenda` | Correcto para el MVP (CLAUDE.md §13); solo apunto que el diseño nuevo no debe perderlo |

Lo que está bien y conviene mantener: máximo 2 propuestas abiertas, bloque de 30 min sin solapes (comprobado en el servidor y con bloqueo de usuarios), «Entrar a la sala» de −5 a +10 min, `no_show` por cron, todo por funciones `svc_*` y RLS estricta.

### 3.2 Alternativas

**A. Reserva directa (modelo «Calendly»).** Quien elige un hueco lo **reserva**: la reunión nace confirmada, la propuesta se cierra (o sigue abierta con los huecos que queden libres, ver más abajo). El creador puede cancelar si no le encaja.
- ➕ Un solo paso; desaparecen L2, L3 y casi todo L4.
- ➖ El creador no «elige» pareja. En una app sin perfiles extensos tampoco hay mucho que elegir, y reportar/bloquear cubre los abusos.

**B. Mantener la solicitud, pero en exclusiva.** Una propuesta admite **una** solicitud a la vez; el creador la acepta o la rechaza con un toque. Mientras está pendiente, la propuesta desaparece del tablón (o caduca a las X horas).
- ➕ El creador conserva el control.
- ➖ Sigue habiendo un paso de espera; una solicitud ignorada bloquea la propuesta.

**C. Lo actual con retoques** (la confirmación del aceptante va implícita al aceptar; el chat se cierra al terminar).
- ➕ Cambio mínimo.
- ➖ Sigue L2 (varios chats compitiendo).

**Compañeros habituales**, en cualquiera de las tres:
- **«Repetir con la misma pareja»** al acabar un examen (pantalla de fin y feedback): abre «Invitar» con la persona ya elegida.
- **Lista «Compañeros»**: alguien entra en ella **solo si los dos os habéis añadido** tras un examen hecho juntos (sin solicitudes de amistad entre desconocidos). Máximo 20. Sin perfil ampliado: nombre, foto, idiomas, nivel y «X exámenes juntos».
- **Invitación directa**: a un compañero, con hora exacta y nivel, dentro de 7 días. La reunión nace confirmada por quien invita y espera **un** toque del otro.
- Nada de estado «en línea», ni feed, ni chat fuera de una reunión.

**Chat siempre ligado a una reunión:**
- Se puede escribir desde que existe la reunión hasta **2 h después** de su hora (para «llego tarde» o «gracias»). Después, solo lectura.
- Los chats de reuniones terminadas hace más de **30 días** se borran (cron de limpieza).
- Mensajes de hasta 500 caracteres (hoy 2000) y respuestas rápidas en la app.

### 3.3 Recomendación

**A (reserva directa) + compañeros con invitación + chat ligado a la reunión.** Es el camino con menos pasos para quedar, convierte cada buen examen en una pareja habitual y cierra por diseño la puerta a la mensajería libre. Encaja con la propuesta del documento de diseño (§9.2 n.º 10 «Repetir con la misma pareja») sin abrir lo que el documento evita.

Detalle de la reserva: la propuesta **sigue abierta con los huecos que queden** (si propongo de 17:00 a 20:00 y alguien reserva las 18:00, las 17:00 y las 19:00 siguen libres para otra persona). Así una franja larga puede dar dos exámenes. Si se prefiere más simple: una reserva cierra la propuesta entera.

### 3.4 Impacto en Supabase (no se toca nada hasta que lo apruebes)

| Pieza | Cambio |
|---|---|
| `meetings` | `origin text check (origin in ('offer','invite'))` y `invited_by uuid`. En reservas, `creator_confirmed = acceptor_confirmed = true` y `status = 'confirmed'` al crear |
| `svc_offer_accept` | Reserva directa: comprueba solapes de los dos, crea la reunión **confirmada** y el chat. Quita la regla «varios aceptantes» (o la limita a huecos distintos). Mantiene `blocked_between` |
| `svc_meeting_confirm` | Solo para invitaciones (un toque del invitado). Desaparece el reparto «cerrar los demás chats de la oferta» |
| `svc_meeting_modify` | Pasa a «proponer otra hora»: la reunión vuelve a pendiente y **solo el otro** confirma. Rejilla de 30 min (L6) |
| `companions` (nueva) | `(user_lo, user_hi, added_lo_at, added_hi_at, sessions_together)`, PK por pareja ordenada; activa si las dos fechas existen. RLS: lectura solo de las filas propias. Escritura solo por `companion_add(p_session)` (deduce al otro de una sesión `ended` de los dos) y `companion_remove(p_user)` |
| `svc_meeting_invite` (nueva) | Exige compañeros activos, elegibilidad, sin solape, `not blocked_between`, máximo 3 invitaciones pendientes |
| `block_user` | Además borra la fila de `companions` de esa pareja y cancela invitaciones pendientes |
| `chat_messages` | Nueva política restrictiva de inserción: la reunión del chat está `pending`/`confirmed` o su hora + 2 h no ha pasado. Límite de 500 caracteres (`check`) |
| `svc_cron_housekeeping` | Borra los chats (y mensajes) de reuniones terminadas hace más de 30 días. *Ojo: contiene `DELETE` → el conector pide confirmación con ventana de 60 s (D-026)* |
| Edge Function `meeting-actions` | Acciones `invite`, `companion_add`, `companion_remove` |
| Tests | Nueva suite `10_companions.sql`; actualizar `04_agenda.sql` (reserva directa) y `09_report_block.sql` (bloqueo borra compañeros e invitaciones) |

Reportar y bloquear (D-044) sigue funcionando: la reserva y la invitación comprueban `blocked_between`; un bloqueo elimina al compañero y cancela invitaciones y reuniones; la política restrictiva de `chat_messages` ya cubre los chats nuevos.

## 4. Orden sugerido

1. Rediseño de interfaz (§2), sin backend. Las tarjetas ya dejan sitio para «Compañeros».
2. Tras tu visto bueno a §3: migración + suite SQL + `meeting-actions` + interfaz de compañeros, invitación y «Repetir con la misma pareja».
