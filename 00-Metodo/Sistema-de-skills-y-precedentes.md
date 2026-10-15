---
tags:
  - metodo
  - grasp
aliases:
  - Regla vs precedente
---

# Sistema de skills y precedentes

> [!note] La pieza más reutilizable de este método
> Si solo te llevas una idea de este vault a un proyecto nuevo, es esta: **separar la regla barata de la
> historia cara**, y cargar la segunda solo cuando hace falta.

## El problema que resuelve

Un proyecto que acumula lecciones de implementación tiene dos fuerzas en tensión:

- Cada lección nueva necesita contexto para no repetirse (qué falló, con qué datos, cómo se detectó).
- Pero ese contexto no puede vivir en el fichero que se carga en **cada** turno de **cada** sesión, porque
  el coste se paga para siempre, narración incluida, aunque esa sesión nunca toque ese dominio.

## El reparto

| Dónde | Qué contiene | Cuándo se carga |
|---|---|---|
| `.claude/CLAUDE.md` (o el agente) | La **regla**: el invariante en una línea, en imperativo, sin narrar el fallo | Cada turno, cada sesión |
| `.claude/skills/<dominio>/SKILL.md` | El **precedente**: qué falló exactamente, la fecha, cómo se detectó, la consulta de auditoría concreta que lo demuestra | Solo cuando se activa esa skill (se toca ese dominio) |

Ejemplo real de Grasp (`CLAUDE.md`, dominio RLS): la regla dice *"RLS protege filas; `GRANT` protege
columnas"* en una línea, con **"Punto 9"** como puntero. El precedente completo — qué tabla, qué columna,
qué consulta contra `information_schema.column_privileges` lo demuestra — vive en
`.claude/skills/rls-security/SKILL.md`, punto 9, y no se repite en `CLAUDE.md`.

> [!important] Autoconsistencia obligatoria
> Si al aplicar una regla el precedente **no aparece** donde el puntero dice que debería estar, eso es un
> fallo del propio sistema de documentación — se corrige en el momento, igual que cualquier otro bug. El
> puntero no es decorativo: es una promesa de que el contexto existe en algún sitio barato de cargar.

## Por qué esto no es solo organización de ficheros

El efecto práctico es que una sesión que nunca toca pagos no paga el coste de leer la historia completa
del ledger de regalos, pero una sesión que sí los toca encuentra automáticamente — porque la skill se activa
por dominio — la lección exacta que evita repetir el fallo. Es un sistema de carga de contexto
**condicionada por tarea**, no por fecha ni por memoria del agente.

## Cómo se transporta a otro proyecto

1. Identifica el fichero "siempre cargado" de tu herramienta de IA (`CLAUDE.md`, `AGENTS.md`, system
   prompt del proyecto, etc.).
2. Cualquier regla nueva entra ahí **en una línea**, con un puntero al documento de dominio.
3. Crea (o reutiliza) un documento por dominio — puede llamarse skill, runbook, playbook — donde vive la
   historia: qué pasó, cuándo, cómo se demuestra que sigue pasando si se rompe la regla.
4. Cuando detectes una regla nueva sin dominio claro donde alojar su precedente, esa es la señal de crear
   el dominio, no de meter la narración en el fichero siempre-cargado "por esta vez".

[[Retroalimentacion-continua]] · [[Documentar-decisiones-como-narrativa]] · [[Como-trabaja-Alfonso]]
