---
tags: [decision, grasp, auth, schema]
aliases: ["ADR 0003"]
---

# 0003 — Migración de OTP a autenticación con contraseña

Se cambia de OTP (sin contraseña) a login/registro con email/teléfono + contraseña + datos de perfil (edad, género). Motivado por preferencia de control del usuario sobre su credencial.

Documento más informal (sin la estructura Contexto/Decisión del resto de ADRs); registra trade-offs y próximos pasos, incluido el password reset que queda pendiente.

Relacionado: precursor de [[0005-registro-sin-email]], que después elimina también la verificación por correo.

[Fichero original](../../docs/decisions/0003-password-auth-migration.md)
