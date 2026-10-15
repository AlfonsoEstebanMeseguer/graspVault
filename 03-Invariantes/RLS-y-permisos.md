---
tags: [invariante, grasp, rls, seguridad]
aliases: [RLS, seguridad de filas y columnas]
---

# RLS y permisos

> Skill origen: `.claude/skills/rls-security/SKILL.md`. Ver [[Esquema-y-migraciones]] (toda tabla nueva necesita las dos a la vez) y [[Ficheros-de-usuario-y-R2]] (RLS no protege el objeto en R2).

## La regla madre

**Deny by default.** `alter table ... enable row level security;` sin policy deja la tabla ilegible/inescribible para todos salvo `service_role`. Nunca se crea una tabla sin su policy explícita en la misma migración.

Dos capas independientes, y hay que auditar las dos:

- **RLS decide qué FILAS** son visibles/escribibles (`using`, `with check`).
- **`GRANT`** decide qué COLUMNAS y qué VERBOS (`select`/`update`/`insert`/`delete`) puede tocar cada rol.

> ⚠️ **RLS filtra filas, nunca columnas.** Si una tabla mezcla datos públicos y sensibles, la frontera tiene que ser **estructural** (dos tablas) o un `GRANT` por columna — nunca "una policy que deje pasar solo lo público".

## Los puntos numerados, con su precedente

| Punto | Regla | Qué falló de verdad |
|---|---|---|
| 6 | RLS filtra filas, no columnas | `profiles` (pública) separada de `profiles_private` (país, categorías Art. 9 RGPD) por necesidad estructural, no por policy |
| 9 | La policy protege la fila; el `GRANT` de columna protege contra que el dueño edite columnas de backend | `profiles` permitía `vip_status=true`/`level=99` vía PATCH con el JWT propio desde el Bloque 1 — nadie lo vio porque dos auditorías revisaron solo policies. Corregido en `20260809120000`, ver ADR [[04-Decisiones/0008-insignias-experiencias-y-grants-de-columna\|0008]] |
| 9b | El `GRANT` por columna aplica también al `SELECT` — "media regla aplicada parece la regla entera" | `profiles` concedía `select` de tabla entera con policy `using(true)`: cualquier registrado volcaba el teléfono de toda la base, indexado, en una app de salud mental. Un año sin detectarse. Hallazgo H-S-01 |
| 9c | A un dato que no lee nadie no se le busca mejor escondite: se borra (Art. 5.1.c) | El teléfono expuesto en 9b: se enumeraron las 4 superficies (pantallas, Edge Functions, login, crons) y ninguna lo leía. Se borró en vez de moverlo a `profiles_private`. Ver ADR [[04-Decisiones/0015-borrar-el-telefono-en-vez-de-esconderlo\|0015]] |
| 11 | `revoke ... from authenticated` no alcanza a `anon` — hay que enumerar roles y verificar contra `information_schema`, nunca deducir de la migración | `anon` mantuvo `UPDATE` sobre **todas** las columnas de `profiles` hasta `20260809140854`. No explotable solo porque las policies eran `to authenticated`, pero una sola capa sostenía todo el peso |
| 12 | `service_role` tiene `BYPASSRLS`, no `BYPASSGRANT` | Una tabla nueva tampoco nace con permisos para `service_role`; el síntoma es el backend entero en 500 en cualquier entorno creado desde cero |
| 13-14 | Los default privileges son del ENTORNO, no del repo, y divergen — se normaliza siempre al más estricto | Local tenía `service_role` con `Dxtm` (sin DML); producción con `arwdDxtm`. Ninguna migración lo causó: producción es anterior al cambio de defaults de Supabase |
| 16 | `set local role` dura toda la TRANSACCIÓN, no el bloque — todo test de `information_schema` empieza con `reset role` | Un test de grants de `anon` heredó `authenticated` de un caso anterior y contaba cero grants pasara lo que pasara. Nació vacuo. Se demuestra mutando la migración para **conceder** el permiso |
| 17 | Publicar una columna de una tabla cerrada se hace con una vista que ENUMERA, nunca abriendo la RLS | La edad sale de `profiles_private` vía `public.public_profiles` con `security_invoker = false`. Añadir una columna al `select` de esa vista **es conceder un permiso** — no queda policy detrás. Ver ADR [[04-Decisiones/0026-la-edad-es-publica\|0026]] |
| 18 | Un caso negativo de RLS afirma el MENSAJE, no solo el `42501` | Ese código es el mismo para «la RLS te rechazó» y para «la policy referencia una columna sin `grant` y no se puede evaluar», y lo segundo falla **para todo el mundo**. Un `throws_ok` sin mensaje pasa en verde sobre una tabla muerta; por eso el caso positivo del miembro legítimo va al lado, como control |
| 9b bis | Cerrar el síntoma no cierra la causa | En agosto se borró el teléfono de `profiles`, pero el `grant select` de tabla siguió: en octubre la misma tabla filtraba `vip_status`, `reputation_score`… Se cerró con `grant select (<columnas>)`, ADR [[0038-profiles-se-lee-por-columnas\|0038]] |
| 15 | Un `UPDATE ... WHERE` lo protegen DOS policies (la del `update` y la del `select` que exige el `WHERE`) — mutar solo una no prueba nada | Relajar solo `update` o solo `select` de `conversation_states` no rompía el test; hicieron falta las dos juntas |

## Tabla de referencia rápida (quién lee/escribe qué)

- `profiles`: lectura **por columnas** para `authenticated` (solo las públicas, ADR 0038); escritura de columnas de usuario por el propio usuario (grant de columna), resto `service_role`. `phone_number` y `language` ya no existen. Lo de otras tablas que es público sale por la vista `public_profiles`.
- `profiles_private` (país, categorías): solo el propio usuario, lectura y escritura.
- `coin_wallets`/`payouts`: lectura propio usuario; escritura solo `service_role`.
- `profiles.photo_path` (el objeto en R2): **RLS no aplica** — ver [[Ficheros-de-usuario-y-R2]].
- `user_follows` en `pending`: NO es pública — revela intención antes de que el otro decida (RN-12).

## Cómo se audita (nunca se lee en la migración)

```sql
select grantee, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public' and table_name = '<tabla>'
group by grantee, privilege_type;
```

## Lección de método que atraviesa toda la skill

> Una regla escrita en una skill se puede leer como si fuera el estado del sistema, y no lo es. El documento dice qué **debe** pasar, nunca qué pasa. Antes de creer cualquier afirmación sobre qué columnas existen o quién las lee, se comprueba contra `information_schema`, no contra el `.md`.

Ver también: [[Edge-Functions-y-reglas-de-negocio]] (el mismo problema de "un valor correcto y uno roto son el mismo byte" aplicado a RPCs).
