---
tags: [decision, grasp, rls, seguridad, rgpd]
aliases: ["ADR 0015"]
---

# 0015 — El teléfono se borra, no se esconde

Hallazgo crítico de auditoría (H-S-01): `profiles.phone_number` era legible por cualquier usuario autenticado (grant de tabla, no de columna, sobre `select`) — en una app de apoyo en salud mental sin verificación de registro, esto habilitaba doxing. "El proyecto decidió lo contrario tres veces y no lo implementó".

**Decisión del usuario**: se borra la columna (no se mueve a `profiles_private`, no se cierra con grants). Justificación de minimización (Art. 5.1.c): hoy no lo lee nadie (login es por email desde [[0005-registro-sin-email]], no hay OTP SMS). Borrar es irreversible pero no se puede volver a filtrar lo que no existe. Origen del punto 9b de `rls-security` ("media regla aplicada parece la regla entera" — el invariante solo se aplicó a escritura, no a lectura).

[Fichero original](../../docs/decisions/0015-borrar-el-telefono-en-vez-de-esconderlo.md)
