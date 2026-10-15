---
tags: [decision, grasp, producto, matching]
aliases: ["ADR 0024"]
---

# 0024 — Relajar el filtro de Conectar solo cambia los pesos, no el conjunto

Dos reglas en conflicto implícito: `RN-41` dice que ningún filtro excluye (solo redistribuye probabilidad, el conjunto de elegibles es idéntico con o sin filtro), pero `RN-49` pide "relajar" cuando no hay suficientes candidatos — lo cual no puede añadir ningún candidato si el conjunto ya era el mismo.

**Decisión**: `relaxed` significa "puntúa sin elevar al cuadrado el multiplicador del filtro activo" — cambia el orden, no el conjunto. Las exclusiones de seguridad (bloqueos) nunca se relajan, se aplican siempre antes. Relacionado con el scoring de [[0020-conectar-no-muestra-datos-del-articulo-9]] (el desglose por eje nunca se serializa).

[Fichero original](../../docs/decisions/0024-relajar-el-filtro-de-conectar-solo-cambia-los-pesos.md)
