---
tags: [decision, grasp, ui, i18n]
aliases: ["ADR 0036"]
---

# 0036 — La app en español e inglés, con selector en Ajustes

Decidido por Alfonso el 2026-10-07. Había unas 470 cadenas escritas a mano en ~70 ficheros, y cada pantalla nueva añadía más: cuanto más tarde, más caro.

**Decisión**: `flutter gen-l10n` con `app_es.arb` y `app_en.arb`. El idioma es una preferencia **del dispositivo** (como el tema, [[0031-modo-oscuro-con-paleta-por-rol|ADR 0031]]), con **inglés** de fábrica. Hay dos puertas: `context.l10n` en todo lo que se pinta y `L10n.current` solo fuera del árbol de widgets (fallos de `data/` y `domain/`). Lo que llega del backend en español (catálogos, insignias) se traduce en el cliente **por `slug`**. Lo que el servidor *comprueba* (la frase de borrado de cuenta) solo se traduce si el servidor acepta también la traducción, y por eso `account-delete` admite «DELETE MY ACCOUNT».

**Lo transferible**: la internacionalización se monta pronto, aunque solo haya un idioma.

[Fichero original](../../docs/decisions/0036-la-app-en-espanol-e-ingles.md)
