---
tags: [decision, grasp, rls, schema, producto]
aliases: ["ADR 0026", "edad publica"]
---

# 0026 — La edad es pública, y se publica con una vista que enumera

El perfil ajeno debía mostrar edad, pero vivía en `profiles_private` (solo lectura propia) y ni siquiera se calculaba/almacenaba en ningún camino.

**Decisión del usuario**: la edad se hace pública vía una vista (`public.public_profiles`) que enumera columnas públicas y calcula `age` al vuelo desde `birth_date` — nunca con una policy `qual = true` directa sobre `profiles_private`, porque eso abriría toda la tabla (categoría de salud mental incluida, ver [[0020-conectar-no-muestra-datos-del-articulo-9]]). `security_invoker = false` es deliberado: la lista de columnas del `select` de la vista **es** la autorización — añadir una columna ahí es conceder un permiso. `birth_date` sigue privada.

[Fichero original](../../docs/decisions/0026-la-edad-es-publica.md)
