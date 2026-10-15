---
tags: [decision, grasp, moderacion, rgpd]
aliases: ["ADR 0043"]
---

# 0043 — Moderación con revisión humana, pánico sin audio y sin reputación

Diseño de la Fase 10 (2026-10-12). El maestro pedía sanciones automáticas («3 reportes disparan la sanción»), reputación dinámica y un buffer de audio de 2 min en el pánico. Alfonso propuso además un reporte de «pánico» para marcar a alguien como mentalmente vulnerable y bloquearle todo. **Claude lo cuestionó antes de diseñar** (principio 0.1) y Alfonso aceptó las cinco correcciones.

**Decisión**: **una máquina detecta, una persona sanciona.** Los reportes (y, en la 10b, un clasificador) llenan una cola, y las sanciones las decide Alfonso con funciones SQL privadas. «3 reportes verificados» son 3 que el moderador ha dado por buenos. La única medida automática es una **cautelar** reversible y sin strike, solo para categorías gravísimas y con 2 denunciantes distintos en 24 h. La escalera de sanciones lleva al **modo restringido** (solo escuchar). Se quitan la reputación y el audio del pánico (el buffer, además, se descartó para siempre).

**Por qué**: una sanción por recuento la dispara una brigada de cuentas coordinadas, y una decisión con efectos significativos sin intervención humana choca con el **Art. 22 RGPD**. Marcar a alguien como enfermo mental es un dato del Art. 9 que no se debe inferir.

**Lo transferible**: un freno cuyo disparador controla el atacante se convierte en un arma; se acota en lugar de automatizarlo.

[Fichero original](../../docs/decisions/0043-moderacion-con-revision-humana.md)
