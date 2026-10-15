---
tags:
  - metodo
  - grasp
aliases:
  - Estilo de los ADR
  - Documentar a fondo
---

# Documentar decisiones como narrativa, no como acta

> [!note] Por qué esta nota existe
> Alfonso pidió explícitamente (2026-08-08): *"reescribe TODA LA DOCUMENTACIÓN relacionada para que se
> entienda y para contexto en futuras conversaciones"*. El estilo de `docs/decisions/` en Grasp no es el de
> un ADR formal de manual — es prosa que cuenta una historia con nombres de columnas, fechas y consultas
> reales.

## El estilo real

Un ADR de Grasp no dice "se decidió usar X en vez de Y por razones de rendimiento". Dice qué pasó, cuándo,
cómo se detectó y con qué se demostró. Títulos reales del repo que ilustran el tono — nótese que **no son
sustantivos abstractos**, son frases que ya cuentan el final de la historia:

- `0015-borrar-el-telefono-en-vez-de-esconderlo.md`
- `0024-relajar-el-filtro-de-conectar-solo-cambia-los-pesos.md`
- `0027-el-bloqueo-deja-de-ser-irreversible.md`
- `0029-cancelar-una-solicitud-enviada-no-existe.md`
- `0030-el-tope-del-pool-de-conectar-se-vigila-en-vez-de-adivinarse.md`

Cada título es ya un resumen ejecutivo de la decisión. Esto es deliberado: alguien que solo lee el
`docs/decisions/README.md` (que es un índice, nunca el contenido) debe poder deducir qué se decidió sin
abrir el fichero.

> [!important] Ninguna ADR se borra
> Una decisión superada se marca en su propia cabecera y se conserva **entera**: el registro de qué se
> pensó y se descartó es el valor del fichero, no un residuo a limpiar. Esto es coherente con
> [[Retroalimentacion-continua]] — el histórico de errores es la materia prima del sistema de precedentes.

## "Documentar a fondo" = barrer todo en el mismo turno

Cuando cambia una decisión de producto o arquitectura, Alfonso espera **una pasada completa**, no una nota
al margen. El barrido real, en orden:

1. `docs/Grasp-ClaudeCode-Bootstrap.md` — el documento maestro, normalmente varias secciones a la vez; si
   el tema es transversal, se crea una **sección de referencia nueva** en vez de esparcir párrafos sueltos.
2. `docs/Grasp-Fase1.md` — si toca el plan operativo de los bloques.
3. `docs/db-schema.md` — si cambia el esquema.
4. `docs/decisions/NNNN-*.md` — ADR nuevo, con Contexto, Decisión, **alternativas descartadas** y
   consecuencias.
5. `.claude/CLAUDE.md` — solo la parte invariante; es lo único que se carga en cada conversación, así que
   se mantiene corto.
6. `.claude/skills/*/SKILL.md` y `.claude/agents/*.md` — sobre todo los **ejemplos de código**, que se
   copian tal cual y propagan el esquema viejo si no se tocan.

Después, un barrido final de referencias cruzadas: renumerar secciones rompe enlaces silenciosamente
(`grep -rn "Sección 24\."` antes de dar el trabajo por hecho).

> [!warning] El `grep` es el suelo, no el techo
> Al corregir una afirmación caducada, la lista de ficheros que se dio como objetivo es el punto de
> partida, no el límite. El criterio es semántico — "cualquier sitio que diga X" — y se persigue con
> `grep` hasta el final. Precedente real: tres agentes distintos lo aprendieron por separado el
> 2026-08-30 al implementar el ADR 0027, y entre los tres encontraron seis ficheros vigentes fuera de la
> lista que se les había dado. Y el `grep` devuelve **falsos positivos legítimos** que no se tocan — hay
> que leer cada resultado, no sustituir en bloque.

## Cómo se transporta a otro proyecto

- Un ADR se titula por su conclusión, no por su tema — el título ya es el resumen.
- Un cambio de decisión dispara una lista de "todo lo que puede repetir la afirmación vieja", y se recorre
  entera en el mismo turno, no se deja para después.
- Nunca se borra un documento de decisión superado: se marca como superado y se enlaza al que lo sustituye.

[[Como-trabaja-Alfonso]] · [[Retroalimentacion-continua]] · [[Sistema-de-skills-y-precedentes]]
