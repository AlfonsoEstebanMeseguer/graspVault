---
tags: [agentes, grasp, metodo]
aliases: [Memoria de agentes, Agent memory]
---

# El patrón de memoria persistente de agentes

Cada subagente con `memory: project` en su frontmatter acumula lecciones en `.claude/agent-memory/<agente>/MEMORY.md` — un **índice** de una línea por entrada, cada una enlazando a un fichero de tema aparte donde vive el detalle (mismo patrón que la propia bóveda con `[[wikilinks]]`, pero en Markdown plano con enlaces relativos). Es la aplicación literal de la "Retroalimentación continua" de `.claude/CLAUDE.md`: la regla se carga siempre, la historia solo cuando hace falta.

> [!info] No todos los agentes tienen memoria real
> De los 12 agentes del equipo, **4 tienen el fichero vacío** (plantilla sin entradas todavía): `agent-factory`, `payments-agent`, `qa-agent`. El resto (8) tiene lecciones reales acumuladas. Esto no es un fallo — simplemente esos agentes no han ejecutado aún tareas reales que produjeran una lección digna de guardar.

## Agentes con memoria real (8)

### `db-agent` (23 líneas, el índice más largo)
- RLS filtra **filas**, nunca columnas — hace falta `GRANT` de columna aparte (el cliente podía ponerse `vip_status = true` hasta que se corrigió el 2026-08-09).
- `revoke execute from public` también le quita `EXECUTE` a `service_role` — mismo invariante BYPASSRLS≠BYPASSGRANT, por el lado de `EXECUTE`.
- El squash de 19 migraciones a 3 (2026-08-16) deja producción **sin reconciliar** todavía.

### `security-agent` (46 líneas)
- **2026-08-05**: auditar RLS leyendo las policies de una en una no basta — las PERMISSIVE se combinan con `OR`, y dos policies "opuestas" pueden ser una tautología equivalente a `using (true)`. `get_advisors(security)` no detectó nada de esto.
- **2026-08-07**: una función `security definer` (`handle_new_user()`) vivía expuesta como RPC pública ejecutable por `anon`/`authenticated` — esta vez sí la detectó el linter automático.

### `audit-leader` (56 líneas, incluye un índice de auditorías)
- No firmar como auditado lo que en realidad verificó el propio orquestador (Bloque 1: el informe se firmó como revisión de pares sin que `reviewer-agent`/`security-agent` llegaran a ejecutarse).
- Auditar código no es auditar lo desplegado — hubo un caso con el código correcto en el repo y el flujo roto en remoto por funciones desplegadas más viejas que los commits.
- Cerrar el ledger de progreso es parte de terminar la tarea, no un extra — quedó obsoleto una vez y mintió sobre el estado real.

### `reviewer-agent` (21 líneas, 14+ patrones de fallo catalogados)
Patrones recurrentes: validación solo en el camino de edición (no en los tres caminos de escritura), `Deno.env.get()!` que no falla con endpoint vacío, auditorías que no leen el diseño antes de decir "falta X", informes que mutan lo que auditan, trazabilidad textual sin enlaces, tests copiados del brief que heredan sus huecos, mutación de widget vacío como técnica para cazar tests de ausencia.

### `dead-code-pruner` (37 líneas)
- **2026-08-16**: se revirtió el borrado de dos tokens de diseño sin uso (`AppColors.success`, `AppMotion.emphasized`) — un token de diseño es un contrato con el sistema de diseño, no un detalle de implementación; su ausencia de uso hoy dice que la pantalla que lo usará no existe todavía, no que sobre. Regla derivada: `core/theming/**` queda fuera del alcance de la poda.

### `frontend-agent` (14 líneas)
Placeholders honestos donde no hay tabla; purga de `phone_number` end-to-end en 9 capas; la mutación del widget vacío (`findsNothing`/`takeException(), isNull` son ciertos sobre la nada — toda ausencia necesita un control positivo); inconsistencia viva `canvas` vs `surface` como fondo de pantalla.

### `backend-agent` (13 líneas)
Contrato fijado en un sitio (cliente y backend documentando lo que "creen" que envía el otro lado diverge en silencio); `service_role` solo cuando RLS no basta, nunca por defecto; `supabase` CLI vuelca las claves (`status` y `start` imprimen `ANON_KEY`/`SERVICE_ROLE_KEY`/`JWT_SECRET` sin filtrar) — ver memoria `grasp-supabase-status-vuelca-las-claves` en la memoria de usuario.

### `context-curator` (13 líneas)
El fallo más repetido de Grasp: un índice que contradice su propio cuerpo porque la cabecera envejece y el cuerpo no (3 casos confirmados); un fichero no se carga por cómo se llama (`.claude/AGENTS.md` nunca se auto-cargó, pese al nombre); "Alfonso: no quites, compacta" — compactar es enlazar, nunca borrar la copia sin dejar rastro.

### `cost-agent` (4 líneas, el más corto con contenido real)
Modelar el **plan**, no el precio unitario (volumen × precio unitario da cifras falsas sin cuota, tramo gratuito recurrente y tope de concurrencia); PITR no viene en Supabase Pro, LiveKit cuesta $50 desde el primer usuario.

## Por qué importa este patrón para un futuro proyecto

Este es probablemente el mecanismo más exportable de todo el repositorio: **memoria de agente versionada en git, estructurada como índice + ficheros de detalle, poblada solo con lecciones reales (nunca rellenada a priori), y escrita explícitamente como vacía cuando no hay nada que decir todavía.** Evita dos fallos opuestos — memoria que crece sin disciplina hasta ser ruido, y memoria que finge experiencia que no existe.

## Ver también

- [[Equipo-de-agentes]]
- [[Historial-de-auditorias]]
