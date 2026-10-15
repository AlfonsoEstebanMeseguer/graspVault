---
tags: [decision, grasp, perfil, rgpd]
aliases: ["ADR 0037"]
---

# 0037 — El perfil ajeno se ve como el propio, sin lo privado

Decidido por Alfonso el 2026-10-07, al abrir un perfil desde la sala en el móvil. El perfil ajeno tenía una ficha propia; ahora usa **los mismos widgets** que el perfil propio (barra de XP, los cuatro contadores, insignias y racha) y solo le falta lo privado: privacidad, edición y borrado de cuenta.

**Decisión**: la vista `public_profiles` gana `xp` y `rooms_joined_count`. `xp` estaba fuera **por minimización**, no por sensibilidad: ahora se pinta, así que se publica. Las «experiencias» del onboarding siguen siendo dato del Art. 9 y no salen; la frontera del [[0020-conectar-no-muestra-datos-del-articulo-9|ADR 0020]] no se mueve. La «insignia destacada» desaparece.

**Lo transferible**: añadir una columna a una vista que enumera **es conceder un permiso** (punto 17 de `rls-security`). «Que se vea igual» se cumple compartiendo el widget, no copiando su aspecto.

[Fichero original](../../docs/decisions/0037-el-perfil-ajeno-se-ve-como-el-propio.md)
