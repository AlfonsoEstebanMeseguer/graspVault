---
tags: [proceso, grasp, skills]
---

# Cómo trabajar en este repo — skills de proceso

> A diferencia de las notas en [[03-Invariantes/Index|03-Invariantes]] (dominios de negocio con precedentes de seguridad), estas skills son **de método**: no dicen qué regla de negocio cumplir, sino cómo pensar, investigar, probar o documentar mientras se trabaja. Se activan automáticamente según la tarea — no hay que invocarlas a mano salvo que el nombre lleve `disable-model-invocation`.

## domain-modeling — afilar el modelo del dominio

Se activa al discutir terminología del proyecto, o al escribir/editar un `GLOSSARY.md` o un ADR. Es una disciplina **activa**: cuestionar términos ambiguos, inventar escenarios límite, cruzar lo que dice el código contra lo que dice el usuario, y escribir la decisión en el momento en que se cristaliza — nunca en batch al final.

Un ADR solo se ofrece cuando las tres son verdad: difícil de revertir, sorprendente sin contexto, y resultado de un trade-off real con alternativas genuinas. Si falta una, no hace falta ADR — este repo tiene uno muy activo en `docs/decisions/` (32 a fecha de este vault).

## diagnosing-bugs — bucle de diagnóstico para bugs difíciles

Se activa cuando el usuario dice "diagnostica"/"depura" o reporta algo roto/lento. **La fase 1 (construir un bucle de feedback rojo/verde) es la skill entera** — bisección, hipótesis e instrumentación solo consumen ese bucle una vez que existe. Nunca se salta a leer código para formar una teoría antes de tener un comando reproducible.

Fases: 1) bucle de feedback tight y rojo-capaz, 2) reproducir y minimizar, 3) 3-5 hipótesis falsables rankeadas (nunca una sola — ancla al primer plausible), 4) instrumentar una variable a la vez, 5) fix + test de regresión en el seam correcto, 6) limpieza (quitar logs `[DEBUG-xxxx]`, confirmar que el repro original ya no reproduce).

## tdd — red-green-refactor con seams acordados

Se activa al construir features o arreglar bugs test-first. Los tests se escriben en **seams acordados de antemano** con el usuario — nunca contra internals. Tres anti-patrones a vigilar: tests acoplados a implementación, tautológicos (el valor esperado sale calculado igual que el código, no de una fuente independiente), y slicing horizontal (todos los tests primero, toda la implementación después — en vez de una rebanada vertical por ciclo).

El refactor **no** es parte del bucle rojo-verde — vive en la fase de revisión (`code-review`).

## code-review — revisión en dos ejes independientes

Se activa al revisar una rama/PR/diff desde un punto fijo. Lanza dos subagentes **en paralelo que no se contaminan entre sí**: uno de **Standards** (¿cumple las convenciones documentadas del repo + una baseline fija de code smells de Fowler?) y otro de **Spec** (¿implementa fielmente lo que pedía el issue/spec original?). Se reportan por separado a propósito — un cambio puede pasar un eje y fallar el otro, y mezclarlos esconde eso.

## research — investigación delegada a un agente en background

Se activa cuando hace falta investigar algo contra fuentes primarias (docs oficiales, código fuente, specs) y el usuario quiere seguir trabajando mientras se lee. El agente de research nunca cita una fuente secundaria que resume otra — sigue cada afirmación hasta la fuente que la posee, y guarda el hallazgo en un `.md` dentro del repo, no solo en el chat.

## pr — plantilla para el cuerpo de un PR

Se activa al escribir la descripción de un PR. Secciones: **Summary** (el diagrama/árbol/pseudocódigo más pequeño que aclara el punto clave — nunca abrumar con todos los formatos a la vez), **Evidence** (antes/después, preferiblemente ejecutable: test que falla y luego pasa), y **Merge Danger** (puerta de un sentido o de dos, y el radio de impacto). Sin preámbulos.

## context-curation — podar documentación y código muerto

Compartida entre `context-curator` y `dead-code-pruner`. La pregunta que ordena todo: **¿esto cuesta contexto en cada sesión, o solo ocupa disco?** Si solo ocupa disco, el problema es que no esté claro si está vigente — la solución casi siempre es una cabecera `Superseded`, nunca un borrado (ADRs y auditorías **nunca** se borran). Si cuesta contexto en cada turno (una línea de más en `CLAUDE.md`, un agente con una tool que no usa), ahí sí se recorta.

Antes de borrar código: la prueba de dependencia se hace con `grep` concreto sobre **todas** las superficies (Dart, Deno, SQL, config, docs), nunca de memoria. Si una superficie no es verificable con confianza, se reporta como "no verificable", no se borra por descarte.

## agent-factory — crear un subagente nuevo

Se activa cuando ningún agente de `.claude/agents/` cubre un rol especializado necesario. Antes de crear, comprobar que no exista ya un agente que pueda ampliarse. El nuevo agente lleva frontmatter obligatorio (`tools` mínimos, nunca "todas por si acaso"), memoria inicial en `.claude/agent-memory/<nombre>/MEMORY.md`, y se registra en `.claude/AGENTS.md`.

## find-skills — descubrir skills instalables del ecosistema abierto

Se activa cuando el usuario pregunta "¿hay una skill para X?" o quiere extender capacidades. Usa `npx skills find` / `skills.sh`, verificando conteo de instalaciones y reputación de la fuente antes de recomendar — nunca recomienda solo por aparecer en la búsqueda.

## implement — ejecutar una spec o un conjunto de tickets

Se activa cuando ya hay una spec o unos tickets cerrados y toca construir. Parte del documento, no de la
conversación: lo que la spec no dice, no se inventa.

## wayfinder — planificar un trabajo que no cabe en una sesión

Se activa ante un bloque de trabajo demasiado grande para una sola sesión. Lo convierte en un mapa de
tickets de decisión que se resuelven de uno en uno hasta que el camino queda claro.

## obsidian-markdown — escribir en este vault

Se activa al crear o editar notas de `graspVault/`: wikilinks, callouts, propiedades, embeds. Convenciones
del vault: [[Home#Convenciones de este vault]].

## El flujo con el que se construyeron las Fases 5–10a (plugin `superpowers`)

Ninguna fase desde la 5 se implementó a partir de una conversación suelta. Todas siguieron estos pasos:

1. **Spec de diseño** (`superpowers:brainstorming`) en `docs/superpowers/specs/AAAA-MM-DD-<tema>-design.md`.
   En la cabecera lleva el estado (**APROBADA por Alfonso** con fecha, luego **IMPLEMENTADA**), los ADR de
   fondo, las secciones del maestro afectadas y los bocetos. Al final, en una sección propia, lo que se
   desvió de la spec al implementarla.
2. **ADR antes del código** cuando la spec cambia una decisión del maestro (0033, 0041, 0043, 0044). Así
   el plan no se inventa el destino.
3. **Plan por tareas** (`superpowers:writing-plans`) en `docs/superpowers/plans/`, cada tarea con su
   Definition of Done verificable.
4. **Ejecución con subagentes** (`superpowers:subagent-driven-development`) en una rama `feat/…`: un
   subagente por tarea y una revisión por tarea. El espacio de trabajo vive en `.superpowers/sdd/<plan>/`,
   que no se versiona. Entre tareas no se pregunta «¿sigo?».
5. **Revisión de la rama entera antes del merge**. Los fallos menores que encuentre se arreglan o se
   anotan en la spec como «se quedan a propósito».
6. **Despliegue y prueba con dos dispositivos reales** contra producción. Las desviaciones van a la spec,
   y las lecciones, a la skill del dominio y a `CLAUDE.md`.

Hasta el 2026-10-13 hay 15 specs y 19 planes. Para un proyecto nuevo, es el patrón que más autonomía da:
la aprobación de Alfonso se concentra en la spec, y el resto avanza sin él.

## supabase / supabase-postgres-best-practices — convenciones de plataforma

Se activan en cualquier tarea que toque Supabase (Auth, Edge Functions, RLS, migraciones, CLI, MCP). Traen su propia checklist de seguridad (que se solapa y confirma la de [[03-Invariantes/RLS-y-permisos|RLS-y-permisos]]: `TO authenticated` solo es autenticación, no autorización; `UPDATE` necesita `WITH CHECK` además de `USING`; `SECURITY DEFINER` en `public` es callable por todos por defecto) y el workflow correcto de migraciones (`execute_sql`/`db query` para iterar, nunca `apply_migration` en bucle). Sesgan hacia verificar contra la documentación actual de Supabase en vez de fiarse del conocimiento entrenado — Supabase cambia rápido.

---

Ver también: [[03-Invariantes/Index|Invariantes de dominio]], [[00-Metodo/Index|Metodología de Grasp]] (cómo se combinan estas skills con el flujo de trabajo real del proyecto).
