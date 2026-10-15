---
tags: [decision, grasp, rls, seguridad, rgpd, producto]
aliases: ["ADR 0020"]
---

# 0020 — Conectar no muestra datos del Art. 9

La spec de Conectar (§6.4) pedía mostrar intereses, categoría y experiencias en la tarjeta — los tres son categoría especial de salud mental (Art. 9 RGPD) y hoy solo los lee su dueño. Publicarlos a cualquier desconocido (sin verificación de registro) habilita acoso dirigido sobre población vulnerable.

**Decisión del usuario, confirmada dos veces**: el scoring se ejecuta entero en servidor (`service_role`) y devuelve solo candidatos — ninguna categoría/experiencia/interés viaja al cliente, tampoco el score interno. Los chips visuales se mantienen pero cambian de contenido a señales no sensibles ya públicas (perfil de oyente, tiempo escuchando, racha, nivel/insignia).

Frontera auditable: "si una respuesta contiene un slug de `categories`/`experience_cases` de otra persona, está mal". Relacionado con [[0026-la-edad-es-publica]] (la edad sola no es Art. 9).

[Fichero original](../../docs/decisions/0020-conectar-no-muestra-datos-del-articulo-9.md)
