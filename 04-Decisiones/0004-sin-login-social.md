---
tags: [decision, grasp, auth, producto]
aliases: ["ADR 0004", "sin login social"]
---

# 0004 — Grasp no ofrece acceso rápido con proveedores sociales

Google y Apple Sign-In se implementaron en UI pero nunca se probaron de extremo a extremo: ambos exigían credenciales de pago (Google Cloud con tarjeta; Apple Developer 99$/año) que no estaban en el plan de un MVP sin ingresos.

**Decisión**: se elimina por completo el código de login social (no se pospone). La única puerta de entrada queda correo/teléfono + contraseña. Sin Apple Sign-In, deja de aplicar la obligación de la App Store de ofrecerlo (solo aplica si se ofrecen otros proveedores sociales).

Mismo día se retiró también el OTP — ver [[0005-registro-sin-email]].

[Fichero original](../../docs/decisions/0004-sin-login-social.md)
