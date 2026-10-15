---
tags:
  - metodo
  - grasp
aliases:
  - Sección 0.2
  - Feedback loop
---

# Bucle de retroalimentación continua

> [!note] Origen
> Sección 0.2 de `docs/Grasp-ClaudeCode-Bootstrap.md`. Es la regla que convierte toda la documentación del
> repositorio (`CLAUDE.md`, `AGENTS.md`, los `SKILL.md`, los agentes, las memorias persistentes) en un
> sistema vivo en vez de un conjunto de notas que envejecen en silencio.

## La regla

**Ningún `.md` de este repositorio es estático.** Cuando se detecta un fallo, una mejora de seguridad, un
cambio de convención o una lección de implementación:

1. Se corrige el problema.
2. Se actualiza el fichero relevante: `CLAUDE.md`, `AGENTS.md`, el `SKILL.md` correspondiente, la
   definición del subagente afectado, o su memoria persistente (`.claude/agent-memory/<agente>/MEMORY.md`).
3. **Esto es una obligación de mantenimiento, no una sugerencia.** Un agente que descubre un patrón
   recurrente y no lo documenta está dejando la misma trampa para la siguiente sesión.

## El reparto regla / precedente

La versión madura de esta regla en Grasp (no solo la 0.2 original, sino cómo se aplica hoy en `CLAUDE.md`)
separa dos cosas que antes se mezclaban:

- **La regla** — el invariante que nunca se rompe — vive en `CLAUDE.md` (o en la definición del agente),
  en **una línea**. Se carga en cada turno de cada sesión, así que cuesta contexto para siempre: tiene que
  ser barata.
- **El precedente** — qué falló exactamente, cuándo, cómo se detectó, la consulta de auditoría concreta —
  vive en el `SKILL.md` del dominio correspondiente. Se lee solo cuando se toca ese dominio.

Ver [[Sistema-de-skills-y-precedentes]] para el detalle de este reparto, que es probablemente la pieza más
reutilizable de todo el método de Alfonso para un proyecto nuevo.

> [!warning] Fallo real si el precedente no aparece
> Si al aplicar una regla el precedente no aparece donde el `CLAUDE.md` dice que debería estar, **eso es
> en sí mismo un fallo** que se corrige en el momento, no se ignora. El sistema se audita a sí mismo.

## Cómo se transporta a otro proyecto

1. Define un fichero "siempre cargado" (equivalente a `CLAUDE.md`) con las reglas en una línea cada una.
2. Cuando una regla necesite contexto — por qué existe, qué pasó la vez que se rompió — ponlo en un
   documento aparte referenciado desde la regla, no en el fichero siempre-cargado.
3. Trata cualquier corrección de comportamiento como una tarea con dos pasos: arreglar el código **y**
   escribir dónde quedó la lección. Si el segundo paso no se hace, la próxima sesión repite el error.

[[Principio-cuestionar-antes-de-implementar]] · [[Sistema-de-skills-y-precedentes]] ·
[[Como-trabaja-Alfonso]]
