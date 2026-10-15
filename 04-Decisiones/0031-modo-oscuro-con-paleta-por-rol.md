---
tags: [decision, grasp, ui, design-system]
aliases: ["ADR 0031", "modo oscuro"]
---

# 0031 — Modo oscuro: la paleta se nombra por rol, no por tono

Grasp gana dos temas (claro/oscuro, + Automático) y los tokens de color pasan de nombrarse por tono (`purple700`) a nombrarse por **rol** (`brandStrong`) vía una `ThemeExtension` (`GraspPalette`) — un token-tono miente la mitad del tiempo en cuanto hay dos temas. La escala oscura no es la clara invertida: tiene tonos propios y ratios de contraste verificados por test, no estimados.

Corolario no obvio: `onBrand` significa "encima del relleno de marca", nunca "blanco" — destapó dos fallos de contraste reales preexistentes. Preferencia guardada en el dispositivo (`shared_preferences`), no en `profiles`, porque es del aparato, no de la persona. Origen del ADR citado en la skill `design-system` y en el invariante de producto/UI de CLAUDE.md.

[Fichero original](../../docs/decisions/0031-modo-oscuro-con-paleta-por-rol.md)
