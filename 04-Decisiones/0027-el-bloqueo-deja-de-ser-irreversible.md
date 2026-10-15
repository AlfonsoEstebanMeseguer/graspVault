---
tags: [decision, grasp, seguridad, producto, mensajeria]
aliases: ["ADR 0027"]
---

# 0027 — El bloqueo deja de ser irreversible, y `RN-23` se enmienda

**Invierte** la decisión de la Fase 4 de que el bloqueo es irreversible desde la app. Se construye `block-remove` (función nueva, no reforma de `block-create` — ver §5 del ADR sobre por qué no `block-toggle`) y la pantalla `Perfil → Privacidad → Usuarios bloqueados`.

**Enmienda a `RN-23`**: desbloquear revela el bloqueo hacia atrás (el desbloqueado puede notar que el tag vuelve a aparecer). Se acepta porque es un acto voluntario de quien bloquea, renunciando a su propia protección — no un secreto ajeno. Lo que sigue intacto: un bloqueo vigente sigue siendo indistinguible de un cupo agotado (ver [[0022-un-solo-texto-para-el-input-inerte]]). Enmendado el mismo día por [[0028-el-bloqueo-es-detectable-por-quien-lo-sufre]].

[Fichero original](../../docs/decisions/0027-el-bloqueo-deja-de-ser-irreversible.md)
