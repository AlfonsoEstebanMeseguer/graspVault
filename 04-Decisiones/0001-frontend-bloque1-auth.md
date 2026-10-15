---
tags: [decision, grasp, ui, auth]
aliases: ["ADR 0001"]
---

# 0001 — Frontend del Bloque 1: bienvenida, login y registro

Login/Registro/Start se derivan de un único boceto (`01-Start_Menu.jpeg`) por falta de bocetos propios. El acceso se planificó inicialmente con 4 métodos (Google, Apple, OTP email, OTP SMS) y login/registro distinguidos por `shouldCreateUser`.

Decisiones de theming duraderas: el CTA primario es un degradado (relleno plano no cumple contraste AA), `GraspMotion` como `ThemeExtension` para animaciones testeables, ilustraciones pintadas con `CustomPainter`.

**Histórico**: los métodos sociales y el OTP se retiraron después — ver [[0004-sin-login-social]] y [[0005-registro-sin-email]].

[Fichero original](../../docs/decisions/0001-frontend-bloque1-auth.md)
