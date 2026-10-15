---
tags:
  - glosario
  - grasp
aliases:
  - RN
  - Reglas de negocio
---

# Glosario de dominio — Grasp

Catálogo de las **reglas de negocio** (`RN-xx`) y términos del dominio de Contactos/Mensajería/Conectar,
extraído de `docs/spec-contactos-mensajes-conectar.md`. Varias han sido enmendadas por un
[[04-Decisiones/Index|ADR]] posterior — se enlaza donde aplica. Esta es la referencia a citar por número
en vez de reabrir el spec completo.

> [!info] Por qué existe esta nota
> El propio repositorio demuestra que un número de regla (`RN-34`) se **duplicó** sin querer durante un año
> (ver RN-55 más abajo). Tener el catálogo en un solo sitio, indexado y enlazado, es la defensa contra ese
> fallo exacto. Ver [[00-Metodo/Documentar-decisiones-como-narrativa]].

## Mensajería directa — primer contacto

| Regla | Resumen |
|---|---|
| RN-01 | Un usuario puede enviar **exactamente 5 mensajes** a quien no le ha aceptado. Ni uno más. |
| RN-02 | El primer mensaje pone la conversación en Contactos del emisor de inmediato; el input se deshabilita al gastar los 5 de RN-01. |
| RN-03 | En el receptor, la conversación vive en **Solicitudes**, nunca en Contactos. |
| RN-04 | El receptor lee el mensaje completo antes de decidir: `Aceptar` / `Ignorar` / `Bloquear` / `Reportar`. |
| RN-05 | `Aceptar` → `ACCEPTED`, pasa a Contactos del receptor, ambos escriben sin límite. |
| RN-06 | `Ignorar` → desaparece de Solicitudes del receptor; **el emisor no se entera de nada**. |
| RN-07 | Tras `Ignorar`/`Bloquear`/`Reportar`, el emisor **nunca** puede volver a iniciar conversación con esa persona. |
| RN-08 | Primer mensaje mutuo y simultáneo entre A y B → `ACCEPTED` automático, hilo fusionado. |
| RN-9 | Si el receptor sigue al emisor, no hay solicitud (va directo). El follow del emisor es irrelevante. |
| RN-10 | El enrutado se evalúa **una sola vez**, al crear la conversación; un follow posterior no la reclasifica. |
| RN-17 | Si un emisor fue ignorado y luego se acepta el follow, la conversación se reanuda en Contactos. |

## Follows (seguidores/seguidos)

| Regla | Resumen |
|---|---|
| RN-11 | Única forma de encontrar a alguien: su **tag exacto** en Conectar. |
| RN-12 | Solicitudes de seguimiento recibidas: `Perfil → Seguidores → Solicitudes de seguimiento`. |
| RN-13 | Aceptar crea `Follow` **unidireccional** (el aceptante no pasa a seguir de vuelta). |
| RN-14 | Aceptar un follow no crea conversación ni la hace visible en Mensajes. |
| RN-15 | Dejar de seguir no afecta a conversaciones ya `ACCEPTED`. |
| RN-16 | Un follow rechazado puede volver a solicitarse (a diferencia del primer mensaje). |
| RN-50–RN-53 | Listas de Seguidores/Seguidos con lógica real: solicitudes de seguimiento independientes, fila con foto/nombre/tag, acciones de dejar de seguir / eliminar seguidor. |

## Límites antispam

| Regla | Resumen |
|---|---|
| RN-18 | Máx. 5 solicitudes de mensaje pendientes simultáneas por usuario. |
| RN-19 | Máx. 5 primeros mensajes enviados al día (ventana móvil de 24h). |
| RN-20 | Máx. 20 solicitudes de seguimiento al día (contador independiente). |
| RN-21 | Al alcanzar un límite, error explícito con cuándo se recupera — nunca fallar en silencio. |

## Bloqueo y reporte

| Regla | Resumen | Enmendada por |
|---|---|---|
| RN-22 | Bloquear archiva la conversación en el lado del bloqueador; el bloqueado pierde toda acción sobre él. | |
| RN-23 | **El bloqueo nunca se revela** — input inerte con texto neutro, idéntico al de "5 mensajes gastados". | [[04-Decisiones/0022-un-solo-texto-para-el-input-inerte\|ADR 0022]], [[04-Decisiones/0027-el-bloqueo-deja-de-ser-irreversible\|ADR 0027]], [[04-Decisiones/0028-el-bloqueo-es-detectable-por-quien-lo-sufre\|ADR 0028]] |
| RN-24 | Un usuario bloqueado queda excluido de Conectar en ambas direcciones. | |
| RN-25 | `Reportar` ejecuta un bloqueo automático y persiste un `Report`. | |

> [!warning] RN-23 no promete lo que parece
> Protege el **contenido** de las respuestas (ninguna nombra el bloqueo), no la capacidad de **inferirlo**
> por tiempos de respuesta o por un input que deja de funcionar. Ver [[03-Invariantes/Edge-Functions-y-reglas-de-negocio]].

## Chat — funcionalidad

| Regla | Resumen |
|---|---|
| RN-26 | Máx. 1000 caracteres/mensaje; contador visible desde los 900; no se trunca en silencio. |
| RN-27 | Borrar historial es solo para quien lo hace; si el otro vuelve a escribir, reaparece **vacía** (solo mensajes posteriores). |
| RN-28 | Borrar mensaje propio (para mí / para todos — con lápida "Este mensaje ha sido eliminado"), editar (tag "editado"), responder (reply/quote). |
| RN-29 | Lista de Contactos ordenada por `last_message_at` descendente. |
| RN-30 | Punto de estado activo/inactivo junto a la foto, excepto en Solicitudes. |
| RN-31 | **No existe confirmación de lectura**, nunca. `unread_count` es estrictamente local del receptor. Ver [[04-Decisiones/0021-mensajeria-sin-confirmacion-de-lectura\|ADR 0021]]. |
| RN-32 / RN-54 | Ocultar estado de actividad es un ajuste de privacidad **reciproco**. |
| RN-33 | Emojis vía teclado del sistema, sin selector propio. |
| RN-55 | El badge de Mensajes no cuenta solicitudes pendientes, solo no leídos de conversaciones aceptadas. |

> [!note] RN-55 nació de un bug de numeración
> Dos reglas distintas compartieron el número `RN-34` (el badge de Mensajes y los chips de Conectar) durante
> un tiempo. El badge se renumeró a `RN-55` el 2026-08-25 porque los chips ya estaban citados en tests
> commiteados — la lección va en [[00-Metodo/Documentar-decisiones-como-narrativa]].

## Conectar — tarjetas y filtros

| Regla | Resumen |
|---|---|
| RN-34–RN-37 | Chips de filtro: selección múltiple, `Todos` por defecto y excluyente, no persiste entre sesiones. |
| RN-38–RN-40 | Tarjeta: tocarla abre el perfil; botón de chat es acción directa; `✕` descarta sin abrir perfil; tras el primer mensaje la tarjeta desaparece en el siguiente refresco. |
| RN-41–RN-43 | Ningún filtro **excluye**, solo redistribuye probabilidad (pondera al cuadrado); sin segmentación dura por edad. Ver [[04-Decisiones/0026-la-edad-es-publica\|ADR 0026]] y [[04-Decisiones/0024-relajar-el-filtro-de-conectar-solo-cambia-los-pesos\|ADR 0024]]. |
| RN-44–RN-46 | Muestreo aleatorio ponderado sin reposición; resultado cacheado en sesión; 20 por tanda, scroll infinito; máx. 5 `pull-to-refresh`/día. |
| RN-47 | Fuera del pool: uno mismo, bloqueados, conversaciones existentes, solicitudes pendientes, ya seguidos, descartados (`ConnectDismissal`). |
| RN-48 | Los rechazados **no reaparecen nunca**. |
| RN-49 | Si no hay candidatos suficientes, relajar el filtro antes que mostrar vacío sin explicación. Ver [[04-Decisiones/0030-el-tope-del-pool-de-conectar-se-vigila-en-vez-de-adivinarse\|ADR 0030]]. |

## Ver también

- [[03-Invariantes/Index]] — invariantes de seguridad por dominio técnico.
- [[04-Decisiones/Index]] — todas las decisiones de arquitectura.
- `docs/spec-contactos-mensajes-conectar.md` — el documento fuente completo, con las enmiendas narradas.
