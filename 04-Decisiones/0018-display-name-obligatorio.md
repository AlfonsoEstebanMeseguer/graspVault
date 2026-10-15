---
tags: [decision, grasp, schema, migraciones]
aliases: ["ADR 0018"]
---

# 0018 — `display_name` obligatorio, y por qué el cambio va dentro del baseline

Una constraint anterior acotaba longitud pero no presencia (`is null or ...` — una CHECK se satisface con `NULL`), dejando tres caminos independientes por los que un perfil podía quedarse sin nombre. Se cierra en tres capas: `not null` + `check` de contenido con `btrim` + validación en trigger de alta + validación en cliente.

**Decisión de proceso, con desacuerdo registrado**: el cambio se funde dentro de `20260816120000_baseline_schema.sql` en vez de ir en migración aparte, pese a la recomendación en contra — invalida el "Camino B" de [[0017-consolidar-las-migraciones-en-tres]]. Lección: "al añadir una barrera al camino de alta, todos los tests que crean usuarios se vuelven sospechosos — los que siguen en verde son más peligrosos que los que se rompen".

[Fichero original](../../docs/decisions/0018-display-name-obligatorio.md)
