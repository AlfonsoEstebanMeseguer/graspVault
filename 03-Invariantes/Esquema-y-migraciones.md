---
tags: [invariante, grasp, db-schema, migraciones]
---

# Esquema y migraciones

> Skill origen: `.claude/skills/db-schema/SKILL.md`. Se usa siempre junto a [[RLS-y-permisos]] — toda tabla nueva necesita las dos en la misma migración.

## Tablas lápida: nunca llevan FK contra lo que entierran

Si una tabla existe para *sobrevivir* a la fila que la origina (cola de borrado diferido, log de auditoría, registro antifraude), no puede referenciar `auth.users` ni a la tabla padre.

- `on delete cascade` → la lápida se borra con el padre; el objeto en R2 queda huérfano **en silencio**.
- `on delete restrict` → el padre no se puede borrar nunca; el derecho de supresión (Art. 17 RGPD) queda bloqueado.

Si la fila la inserta un trigger `before delete` durante la cascada del padre, la FK ni siquiera se puede satisfacer: el padre ya no existe cuando el trigger corre. `user_id` se queda como `uuid not null` **sin** `references`, documentado con un `comment on column`. Precedente: `storage_gc_queue` y `photo_audit_log`.

Corolario de testeo: un test que hace `delete from public.profiles` no prueba el borrado de cuenta real — solo `delete from auth.users` llega por cascada y es el camino del RGPD. Ver memoria `grasp-probar-el-camino-real-de-borrado`.

## La validación vive en el camino de ESCRITURA, no en el de edición

Antes de confiar en una validación, enumerar **todos** los caminos por los que puede nacer una fila (trigger de alta, importación, webhook), no solo el que se está tocando. Donde la regla sea inmutable, va como `check` de columna — una constraint no la salta ningún camino.

Precedente: `handle_new_user` copiaba `raw_user_meta_data` sin aplicar las mismas reglas que `profile-update` (edad, longitud de nombre). La barrera de edad no se aplicaba en el único sitio donde se crean cuentas. Al subir la edad mínima a 18 ([[0044-edad-minima-18|ADR 0044]]) se aplicó en los dos caminos a la vez, y en la Fase 10a aparecieron más caminos de escritura directa del perfil que también tuvieron que respetarla.

Matiz: una `CHECK` acota el CONTENIDO, no la AUSENCIA — `check (col in ('a','b'))` deja pasar un `NULL`. Hacen falta dos constraints. Y `char_length('   ')` es 3: sin `btrim`, los espacios cuentan como contenido.

## Contadores: ¿se puede RECALCULAR?

Antes de copiar el patrón de un contador, comprobar si el nuevo se puede recalcular desde una tabla fuente:

| | Recalculable (`followers_count`) | No recalculable (`unread_count`) |
|---|---|---|
| Mecanismo | Función que recalcula | Trigger `after insert` en la misma transacción que su causa |
| Si falla una llamada | Se arregla sola en la siguiente | Daño **permanente e indetectable** — no hay consulta que delate la deriva |

Corolario de diseño: si el efecto va en un trigger, va **todo** el efecto junto (`last_message_at`, `unread_count`, `hidden`) — repartirlo entre el trigger y el handler reabre la ventana de inconsistencia.

## Crons: `pg_cron` desde una migración, nunca `config.toml`

El CLI de Supabase no tiene clave `schedule` para funciones — la ignora en silencio (o `db reset` aborta con `has invalid keys`). El cron de RGPD de media-gc estuvo "programado" en `config.toml` todo el Bloque 3 sin existir en ningún entorno.

El envoltorio del cron va en un esquema `private` fuera de `api.schemas` (nunca en `public`, o PostgREST lo expone como RPC público — ver punto 11 de esta misma skill sobre `security definer`). Los secretos van en Supabase Vault, nunca en la migración en texto plano.

Verificación real (no basta con que el job diga `succeeded` — eso solo dice que el SQL corrió, pg_net es asíncrono):
```sql
select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;
select id, status_code, left(content, 200) from net._http_response order by id desc limit 5;
```

### Verificar un cron con relojes movidos (punto 11d)

Hace falta un **control de casi-fallo en la misma pasada**, y su margen tiene que sobrevivir a la latencia del tic. El reloj no se para mientras esperas: un control a 9 minutos de un umbral de 10 cruza el umbral antes de que el barrido lo mire y se cierra, y «el control se cerró» es el mismo síntoma que el fallo que buscas. Cada caso vencido cumple **una sola** condición, o el motivo que se escribe no discrimina. Se afirma sobre los ids sembrados, nunca sobre el contador que devuelve la función.

## Realtime: la tabla entra en `supabase_realtime` en su migración (punto 14c)

El fallo es **mudo**: RLS y grants perfectos, un `insert` que funciona y ni un evento entregado, sin error en ninguna capa. Se comprueba en `pg_publication_tables`, nunca leyendo la migración. Y aun bien configurada, un evento se pierde si llega mientras el canal se monta: el cliente relee al quedar `SUBSCRIBED`.

## Idempotente no es «seguro de reaplicar» (puntos 14 y 14b)

Reaplicar entera una migración vieja **revierte** lo que una posterior le enmendó sobre los mismos objetos, aunque cada sentencia sea `create or replace` / `if not exists`. Antes de reaplicar, se busca en las migraciones **posteriores** quién redefine lo que toca.

## `apply_migration` permitido, con canonización en el mismo turno (punto 14e)

El MCP registra su propio `version` (el instante), no el del fichero. En el mismo turno se renombra el fichero local a ese `version`, o el siguiente `db push` aborta y propone revertir cambios reales. ADR [[0034-apply-migration-permitido-con-canonizacion|0034]].

## Autenticación de funciones internas: token dedicado, nunca `verify_jwt` ni `SERVICE_ROLE_KEY`

- `verify_jwt` lo cumple la `anon key`, embebida en la app — no autentica nada interno.
- `SUPABASE_SERVICE_ROLE_KEY` cambia de formato sin avisar (Supabase pasó de JWT legacy a `sb_secret_…` el 2026-08-10 y el cron devolvió 401 sin que nadie tocara código).

Patrón `requireInternalCaller`: el token vive en Vault, la función solo conoce su **hash SHA-256**, compara en tiempo constante, **falla cerrado**. Ver ADR [[04-Decisiones/0011-token-dedicado-para-crons-internos\|0011]].

> Corolario general, y uno de los [[03-Invariantes/Index|principios de todo el repo]]: si solo hay que comprobar "¿conoce el secreto?", el verificador guarda el hash. Ningún secreto se copia a mano entre sistemas.

## Otras reglas de la skill

- `search_path` en funciones `security definer`: siempre `= ''`, **nunca entre comillas** como lista — `set search_path = 'a, b'` es un único esquema inexistente llamado literalmente `a, b`, y Postgres cae al `pg_catalog` implícito sin avisar.
- Toda función `security definer` en `public` revoca `EXECUTE` de `anon`/`authenticated` explícitamente — PostgREST la expone como RPC por defecto.
- Timestamps solo si alguien los lee; `updated_at` exige trigger o la columna miente.
- El ejemplo de `direct_messages` en la skill llegó a traer `read_at` y `deleted_at` genéricos que violaban ADRs posteriores (0021, mensajería sin confirmación de lectura) — **un bloque de código de ejemplo se copia literalmente, pesa lo mismo que una regla**.

Ver también: [[RLS-y-permisos]], [[Edge-Functions-y-reglas-de-negocio]] (punto 10, "un `db push` no es un deploy de código").
