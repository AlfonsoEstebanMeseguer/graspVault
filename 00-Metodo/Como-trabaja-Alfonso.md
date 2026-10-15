---
tags:
  - metodo
  - grasp
aliases:
  - Perfil del usuario
  - Alfonso
---

# Cómo trabaja Alfonso

> [!note] Para quién es esta nota
> Si eres un agente de IA generativa arrancando un proyecto **nuevo** (no Grasp) con este usuario, esto es
> lo primero que necesitas saber de él antes de escribir una línea de código.

Alfonso construye [Grasp](../Home.md) **en solitario**. Sabe de producto y de código, pero **la
infraestructura la está aprendiendo sobre la marcha** — dijo literalmente "nunca he trabajado con archivos
multimedia" antes de decidir la arquitectura de almacenamiento (2026-08-08, ver
[[Almacenamiento-R2-y-voz]]). Esto no es una debilidad a esconder: es un dato operativo. Significa
que las explicaciones de infraestructura (buckets, RLS, tokens, CLI) deben ser completas, no asumidas como
sabidas.

## Rasgos observados

- **Pide los clics exactos.** Cuando hay que tocar un panel externo (Cloudflare, Supabase), quiere la
  navegación concreta paso a paso ("ve a Settings → API → ..."), no "crea un bucket". Agradece que se le
  diga explícitamente qué **no** hay que hacer, no solo qué sí.
- **Decide rápido si le das una recomendación con sus contrapartidas.** No quiere un catálogo neutro de
  tres opciones; quiere una postura razonada con un motivo. Y discute cuando no le convence — su
  contraargumento sobre usar R2 desde el principio (porque igualmente lo necesitaría para los audios de la
  Fase 10) era correcto y cambió la decisión. Esto significa: **dar una recomendación por defecto, no una
  lista exhaustiva**, y esperar que la cuestione si no cuadra.
- **Todo en español.** Resúmenes, explicaciones, preguntas, nombres de test, comentarios SQL/Deno — ver
  [[Documentar-decisiones-como-narrativa]]. Los identificadores de código siguen en inglés. Las
  descripciones de test en español van **sin tildes** por convención del repo.
- **Trata los `.md` del repo como spec ejecutable, no como apuntes.** Cuando cambia una decisión, espera
  que se reescriba **toda** la documentación afectada en el mismo turno — ver
  [[Documentar-decisiones-como-narrativa]].
- **Terminal en Windows + Git Bash, Docker Desktop no siempre arrancado.** Herramientas Unix habituales
  (`psql`) pueden no estar en el `PATH` — ver [[Seguridad-higiene-de-secretos]] para el patrón de
  verificación que sustituye a asumir que algo existe.

## Qué NO hacer

> [!warning] Errores ya cometidos con este usuario — no repetirlos
> - **No asumir que algo existe** (un MCP, una herramienta, un fichero, una variable de entorno) sin
>   comprobarlo primero. Ver el principio "antes de cualquier cosa" en `CLAUDE.md`.
> - **No pedir que pegue un secreto en el chat**, ni leerlo del `.env` con `cat`. Ver
>   [[Seguridad-higiene-de-secretos]] — ya ha pegado claves secretas por error más de una vez, y una
>   acabó en un fichero versionado.
> - **No dar algo por "implementación completa" sin reconstruir el entorno desde cero** y recorrer el
>   flujo real. Ver [[Memoria-persistente-y-verificacion]] — hubo 17 commits en `master` que parecían
>   buenos y escondían tres bloqueantes que ningún test detectaba, porque el entorno viejo tapaba los
>   fallos.
> - **No dar por buenos sus datos de configuración pegados a mano** (endpoints, nombres de bucket, IDs)
>   sin verificarlos: en una sola sesión pegó un endpoint con el bucket incrustado, otro con `hhttps://`,
>   uno sin la parte `.eu.`, y una variable mal escrita (`CLOUD_FLARE_` en vez de `CLOUDFLARE_`). Ninguno
>   habría dado un error legible por sí solo.
> - **No implementar en silencio algo que parece inseguro o mal planteado** solo porque es lo que pidió.
>   Ver [[Principio-cuestionar-antes-de-implementar]].

## Notas relacionadas

[[Principio-cuestionar-antes-de-implementar]] · [[Retroalimentacion-continua]] ·
[[Documentar-decisiones-como-narrativa]] · [[Memoria-persistente-y-verificacion]] ·
[[Seguridad-higiene-de-secretos]] · [[Sistema-de-skills-y-precedentes]]
