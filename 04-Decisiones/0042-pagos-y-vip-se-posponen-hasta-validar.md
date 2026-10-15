---
tags: [decision, grasp, producto, roadmap]
aliases: ["ADR 0042"]
---

# 0042 — Pagos y VIP se posponen hasta validar la app

Decidido por Alfonso al cerrar la Fase 7 (2026-10-11). Sin usuarios no se sabe si los pagos merecen la pena, y montarlos cuesta mucho: RevenueCat, perfil fiscal, sandbox y, sobre todo, **regalos con retiradas de dinero** (verificación de identidad, antifraude, carga legal).

**Decisión**: las Fases 8 (gifts y pagos), 9b (cobro de VIP) y 11 (gamificación completa), y el interstitial, van **después de validar**. Orden hasta el lanzamiento: topes de coste de voz ([[0041-tope-diario-de-minutos-en-salas|0041]]) → 9a, VIP sin cobro (añadida el mismo día) → Fase 10, moderación → Fase 13, analytics (adelantada) → Fase 12 recortada (push y anuncios con recompensa) → Fase 14, hardening → lanzamiento.

Claude advirtió que la 9a retrasaba la moderación. Se aceptó porque era pequeña, con la condición de que volviera detrás si crecía.

**Pendiente**: qué cuenta como «validado». Se fija al cerrar la Fase 13, con métricas reales delante.

**Lo transferible**: el orden de fases se decide por **riesgo** (coste descontrolado, usuarios vulnerables) y por lo que hace falta para decidir, no por la numeración del plan original.

[Fichero original](../../docs/decisions/0042-pagos-y-vip-se-posponen-hasta-validar.md)
