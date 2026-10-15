---
tags: [decision, grasp, seguridad, rgpd, edge-functions]
aliases: ["ADR 0016"]
---

# 0016 — El borrado de cuenta exige contraseña, no solo sesión

No existía **ninguna** forma de borrar una cuenta pese a que la cascada RGPD (Art. 17) estaba construida y probada — origen del principio "un mecanismo sin puerta de entrada no existe" (CLAUDE.md, Principios generales). Bloqueaba además la publicación en App Store/Google Play.

**Decisión**: Edge Function `account-delete` con tres barreras: JWT + contraseña actual (reautenticación — una sesión no basta, cualquiera con el móvil desbloqueado la tiene) + frase de confirmación `BORRAR MI CUENTA` comprobada en backend. `photo_audit_log` sobrevive 90 días por diseño (Art. 6.1.c), y la UI lo dice explícitamente.

[Fichero original](../../docs/decisions/0016-borrado-de-cuenta-con-reautenticacion.md)
