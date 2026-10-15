---
tags: [decision, grasp, mensajeria, ui]
aliases: ["ADR 0040"]
---

# 0040 — Las solicitudes de mensaje se ven en una burbuja morada

Enmienda a `RN-55` (2026-10-08). Las solicitudes quedaban fuera de la burbuja roja «para no premiar el spam», pero entonces quien recibía una no se enteraba. Además, la bandeja se cargaba una sola vez y ninguna burbuja se movía.

**Decisión**: una burbuja **morada** «+N» (`CountBubble`) en la pestaña Solicitudes y en el icono de Mensajes. La roja no cambia: solo cuenta mensajes no leídos de conversaciones aceptadas. El lector de pantalla oye las dos. La bandeja se relee sola cada 30 s y al volver a primer plano. El número sale de `requests_count` del backend, no del largo de la lista, y una solicitud ignorada no cuenta.

**Lo transferible**: un indicador que no se refresca miente tanto como uno que no existe.

[Fichero original](../../docs/decisions/0040-las-solicitudes-se-ven-en-morado.md)
