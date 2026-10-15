---
tags: [agentes, grasp]
aliases: [Subagentes, Agent team]
---

# Equipo de subagentes de Grasp

La sesión principal actúa como orquestador por defecto — no hay un agente "leader" independiente excepto para auditoría (`audit-leader`). Cada subagente vive en `.claude/agents/<nombre>.md` (frontmatter = única autoridad sobre `tools`/`model`) y acumula lecciones en su propia memoria — ver [[Patron-de-memoria-de-agentes]].

**Solo `audit-leader` lleva la tool `Agent`** en su frontmatter: el árbol de invocación tiene una sola raíz y el coste es predecible. Ningún otro especialista delega, aunque su prosa describa a quién podría invocar.

| Agente | Modelo | Tools | Rol | Cuándo se invoca | Rasgo distintivo |
|---|---|---|---|---|---|
| `db-agent` | sonnet | Read, Write, Edit, Bash | Migraciones SQL, RLS, seed data | crear/modificar esquema, tablas, policies, `seed.sql` | Comprueba el estado real con el MCP de Supabase antes de asumir qué existe; nunca copia el SQL de un patrón sin mirar el ACL real |
| `backend-agent` | sonnet | Read, Write, Edit, Bash | Edge Functions, contratos API, crons | crear/modificar una función o su contrato en `docs/api-contracts.md` | Coordina con `qa-agent` y con `security-agent` si toca pagos/saldo/webhooks |
| `frontend-agent` | sonnet | Read, Write, Edit, Bash | Pantallas Flutter, theming, `VoiceService` | crear/modificar cualquier pantalla o widget | Regla obligatoria: visualizar el boceto en `pictures/screens/` antes de maquetar; si falta, preguntar — nunca improvisar |
| `payments-agent` | sonnet | Read, Write, Edit, Bash | RevenueCat, ledger de gifts/monedas, entitlements VIP | tocar monedas, gifts, compras, suscripción VIP | El % de comisión es constante configurable, nunca hardcodeada; antifraude ante regalos circulares |
| `security-agent` | opus | Read, Grep, Bash | Auditoría RLS, rate limiting, antifraude, webhooks | antes de mergear cualquier cambio con superficie de seguridad | Aplica el "principio 0.1" (cuestionar incluso lo no preguntado); checklist de 12+ puntos de la Sección 10/21 del maestro |
| `qa-agent` | sonnet | Read, Write, Edit, Bash | Tests unitarios/integración/carga | al cerrar un bloque/fase | No marca un DoD como cumplido sin prueba real; dice explícitamente cuándo un DoD es ambiguo o no verificable |
| `reviewer-agent` | opus | Read, Grep, Glob, Bash | Revisión de código/planes antes de mergear | proactivamente al cerrar cada bloque/fase | Mismo "principio 0.1": señala metodología/arquitectura mejorable aunque nadie lo pregunte |
| `audit-leader` | opus | Read, Write, Edit, Bash, Grep, Glob, **Agent** | Auditoría iterativa de bloques completos contra el DoD | al cierre de cada bloque/fase | Única raíz de delegación del equipo; coordina a `qa-agent`, `reviewer-agent` y `security-agent` |
| `cost-agent` | opus | Read, Write, Edit, Grep, Glob, WebSearch, WebFetch | Coste de infraestructura, unit economics | elegir proveedor, dimensionar, estimar factura, costear abuso | Todo precio se verifica por `WebSearch`/`WebFetch` contra la página del proveedor, nunca de memoria; se modela en 3 escenarios (100/1.000/10.000 UAM) y se incluye el coste del abuso |
| `context-curator` | opus | Read, Write, Edit, Grep, Glob, Bash | Cura `docs/`, `CLAUDE.md`, `AGENTS.md`, skills, memorias | documentación contradictoria o caducada | Regla de oro: "ante la duda, se conserva" — nunca borra un ADR, auditoría o precedente, solo marca lo superado |
| `dead-code-pruner` | opus | Read, Write, Edit, Grep, Glob, Bash | Quita código muerto/duplicación real en `apps/mobile/lib` y `apps/backend/supabase/functions` | código inalcanzable o duplicado | Prohibición absoluta: nunca toca `apps/backend/supabase/migrations/` — es historia inmutable |
| `agent-factory` | sonnet | Read, Write, Edit | Crea nuevos subagentes/skills | ninguna especialización actual cubre la necesidad | Nunca duplica un rol que ya cubre otro agente existente |

## Modo de trabajo por defecto

Subagentes clásicos (más baratos y predecibles): la sesión principal delega una tarea, el subagente la ejecuta y devuelve el resultado. El modo experimental "Agent Teams" (paralelismo real con comunicación entre agentes) es opcional, solo para trabajo pesado.

## Ver también

- [[Patron-de-memoria-de-agentes]] — qué han aprendido realmente estos agentes
- [[Historial-de-auditorias]] — el trabajo real de `audit-leader`, `reviewer-agent` y `security-agent` documentado
- `.claude/AGENTS.md` y `.claude/agents/<nombre>.md` — fuente original, autoridad sobre `tools`/`model`
