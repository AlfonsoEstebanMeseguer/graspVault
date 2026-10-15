---
tags: [decision, grasp, auth, seguridad]
aliases: ["ADR 0005"]
---

# 0005 — Grasp no envía correos: el alta crea la cuenta y abre sesión

El SMTP gratuito de Supabase (≈2 correos/hora) agotaba su cuota con una sola prueba de registro, y con "Confirm email" activo `signUp` no devolvía sesión — la navegación reactiva de Grasp se quedaba muda tras registrarse.

**Decisión**: se desactiva la confirmación de email y se elimina toda la superficie de verificación OTP (`AuthChannel`, `sendLoginCode`, `verifyCode`, etc). El email se queda como identificador de login, pero sin verificarse.

**Consecuencia asumida**: cualquiera puede registrarse con un correo que no es suyo; crear cuentas desechables para acosar sale gratis — pesa especialmente en una app de apoyo entre iguales. Debe revertirse antes de publicar (SMTP propio + confirmación). El teléfono recogido deja de validarse — precedente que [[0015-borrar-el-telefono-en-vez-de-esconderlo]] cierra borrando la columna.

[Fichero original](../../docs/decisions/0005-registro-sin-email.md)
