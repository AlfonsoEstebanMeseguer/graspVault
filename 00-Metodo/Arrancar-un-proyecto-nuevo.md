---
tags:
  - metodo
  - plantilla
aliases:
  - Plantilla de proyecto
  - Bootstrap de un proyecto nuevo
---

# Arrancar un proyecto nuevo usando Grasp como plantilla

> [!abstract] Para quién es esta nota
> Para Claude Code al empezar un proyecto parecido a Grasp (app móvil + backend gestionado + datos
> personales). Su objetivo es que el proyecto nuevo trabaje con autonomía desde el primer día. Para eso
> hereda el **método** y las **lecciones generales** de Grasp, nunca sus reglas de negocio.

## 1. Qué se copia y qué no

| Pieza de Grasp | ¿Se copia? | Cómo |
|---|---|---|
| Estructura de `.claude/CLAUDE.md` (Antes de cualquier cosa · Invariantes por dominio → skill · Principios generales · Retroalimentación continua · Comandos · Convenciones · Orden de trabajo) | **Sí, la estructura** | Se reescribe el contenido. Los invariantes de seguridad de datos (RLS/GRANT, secretos, service role, reautenticación) casi siempre aplican tal cual si el stack es Supabase |
| Skills de dominio (`rls-security`, `db-schema`, `edge-functions`, `media-storage`, `flutter-ui`, `design-system`) | **Sí, si el stack coincide** | Se conservan las reglas y se **recortan los precedentes** a los que sigan siendo útiles fuera de Grasp |
| Skills específicas (`voice-service`, `gifts-ledger`) | Solo si el producto tiene voz o monedas | — |
| Skills de proceso externas (`tdd`, `code-review`, `diagnosing-bugs`, `wayfinder`, `research`, `implement`, `pr`, `domain-modeling`, `find-skills`, `obsidian-markdown`, `supabase`) | **Sí** | Con `npx skills add` usando las fuentes de `skills-lock.json`; viven en `.agents/skills/` con enlace desde `.claude/skills/` |
| Agentes (`.claude/agents/`) | **Sí**, menos los de dominio que no apliquen (`payments-agent`) | Las memorias de `.claude/agent-memory/` **no** se copian: son historia de Grasp |
| `docs/decisions/README.md` (formato de ADR) | **Sí** | Se empieza en 0001. Los ADR de Grasp no se copian, pero sus «lecciones transferibles» ya están en este vault |
| Flujo spec → ADR → plan → subagentes → revisión → dos dispositivos (plugin `superpowers`) | **Sí** | Detalle en [[Como-trabajar-en-este-repo\|05-Skills-de-proceso]], apartado «El flujo con el que se construyeron las Fases 5–10a» |
| Documento maestro + plan de arranque por bloques con DoD | **Sí, el patrón** | Un maestro con la Sección 0.1 ([[Principio-cuestionar-antes-de-implementar]]) y 0.2 ([[Retroalimentacion-continua]]) antes que el stack |
| `graspVault/00-Metodo/` | **Sí, entera** | Es la parte transferible; el resto del vault es de Grasp |
| `.claude/settings.json` | Solo `enabledPlugins` y permisos genéricos | **Nunca** `defaultMode: bypassPermissions` en el fichero compartido: es una preferencia personal y va en el `settings.local.json` de cada uno |
| `scripts/sync-public.ps1` | Opcional | Solo si el proyecto tiene una versión pública del repo |

## 2. Orden de arranque que funcionó

1. **Bloque 0, entorno**: comprobar herramientas, MCPs y cuentas *antes* de usarlos (Docker y Deno eran
   bloqueantes en Grasp). No asumir nada instalado.
2. **Tokens de diseño y tema** desde el primer bloque de UI, por rol y no por tono (dos temas desde el
   principio sale más barato que migrar después). Lo mismo con la **internacionalización**: en Grasp se
   adelantó tarde y costó ~470 cadenas.
3. **Esquema con RLS + GRANT por columnas desde la primera tabla**, auditado contra `information_schema`.
   En Grasp, olvidar el `SELECT` por columnas costó dos incidentes en la misma tabla.
4. **Borrado de cuenta con su puerta de entrada** (pantalla + función + reautenticación) antes de publicar:
   las tiendas lo exigen, y un mecanismo sin puerta no existe.
5. **Topes de coste del recurso que se paga por uso** (minutos de voz, almacenamiento) antes de abrir a
   nadie. Se calcula el coste del **abuso**, no del usuario medio.
6. **Moderación y edad mínima antes de que entre gente de fuera**, si hay contacto entre desconocidos.
7. **Analytics antes que pagos**: los pagos se deciden con datos.
8. **CI desde el principio.** En Grasp sigue pendiente y obliga a correr `flutter analyze`, `flutter test`
   y `deno test` a mano antes de cada merge.

## 3. Cómo se trabaja con Alfonso (resumen; detalle en [[Como-trabaja-Alfonso]])

- Todo en español. Recomendación razonada y **una** opción marcada, no un catálogo.
- En un plan por tareas no se pregunta «¿sigo?» al cerrar cada una.
- Nunca leer ni pedir el valor de un secreto ([[Seguridad-higiene-de-secretos]]).
- `git add` fichero a fichero: suele haber ficheros suyos sin seguimiento.
- Una fase se cierra cuando se ha probado en un dispositivo real y contra el entorno real, no cuando los
  tests pasan ([[Memoria-persistente-y-verificacion]]).

## 4. Señal de que la plantilla funciona

El proyecto nuevo deja de depender de Alfonso cuando cada fallo encontrado acaba en tres sitios: la
corrección en el código, una línea de regla en `CLAUDE.md` y su precedente en la skill del dominio
([[Sistema-de-skills-y-precedentes]]). Si una lección se queda solo en el chat, el siguiente proyecto la
vuelve a pagar.

[[Index|Volver al índice del método]]
