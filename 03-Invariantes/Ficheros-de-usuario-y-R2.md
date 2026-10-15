---
tags: [invariante, grasp, media-storage, r2, rgpd]
---

# Ficheros de usuario y R2

> Skill origen: `.claude/skills/media-storage/SKILL.md`. Hoy el único caso vivo es la foto de perfil. El buffer de audio del botón de pánico se descartó ([[0043-moderacion-con-revision-humana|ADR 0043]]), así que Grasp no guarda audio: la mensajería es de texto (ADR 0006).

## Las cinco reglas que no se rompen

1. **Los bytes nunca entran en Postgres.** En la fila va solo la clave del objeto (`avatars/<user_id>/<uuid>.webp`), nunca los bytes ni la URL completa.
2. **El fichero nunca atraviesa una Edge Function.** El cliente sube/descarga directo contra R2 con URLs prefirmadas.
3. **Las credenciales de R2 son de backend**, como `service_role` — jamás en Flutter.
4. **RLS protege la fila, no el objeto.** Postgres y R2 no se conocen; la autorización del fichero se comprueba en la función que firma la URL. Ver [[RLS-y-permisos]] § "RLS protege la fila, no el fichero".
5. **Borrar la fila no borra el fichero.** Sin cascada explícita a R2, el borrado de cuenta no cumple RGPD aunque la tabla quede vacía.

## Cascada de borrado — la trampa principal

`on delete cascade` borra la fila **y la clave con ella**, dejando el objeto huérfano e imposible de localizar. Y pasa por cualquier vía de borrado, no solo la Edge Function (dashboard, `auth.admin.deleteUser`, SQL manual).

Patrón correcto: trigger `BEFORE DELETE` que encola la clave en `storage_gc_queue` **antes** de que la fila desaparezca. Esa tabla cola es una **tabla lápida** (ver [[Esquema-y-migraciones]]) y por eso no lleva FK contra `auth.users`: el trigger corre durante la cascada del usuario, cuando esa fila ya no existe.

`media-gc-cron` drena la cola cada 5 minutos. Fallar una vez no puede ser definitivo — la fila se queda en `pending` con reintentos (`attempts`, `last_error`) y solo pasa a `failed` (terminal, requiere ojo humano) al agotarlos.

Prueba por el camino real: `delete from auth.users`, nunca `delete from public.profiles` — el segundo funciona aunque el primero esté roto.

## Barrido de huérfanos (`media-reconcile-cron`)

Una URL prefirmada emitida y nunca confirmada no está en ninguna tabla: no entra en la cola de GC y sobrevive al borrado de cuenta. El barrido compara el inventario real del bucket contra la BD y encola lo que nadie reclama. **Nunca borra** — quien borra sigue siendo `media-gc-cron`.

**Hoy solo conoce `avatars/`** (`KNOWN_PREFIXES` en `_shared/reconcile.ts`). Dar de alta un bucket nuevo exige DOS cambios, no uno: añadir el prefijo **y** extender el conjunto referenciado con su tabla — dar de alta solo el prefijo es **peor que no barrer nada** (convierte objetos vivos en candidatos a borrado).

### El freno de emergencia: acotar, no abortar (H-S-03)

`evaluateBrake` distingue dos clases de fallo por **de quién se está fiando** el barrido:

- **Abortan** (encolan cero): se duda del conjunto referenciado — la consulta falla, o sale vacía mientras el bucket no lo está, o se leyó incompleta. Un "huérfano" aquí podría ser un avatar vivo.
- **Acotan** (procesan parte): el conjunto está verificado completo, los huérfanos son huérfanos de verdad y solo son muchos (tope absoluto o proporción anómala >50%).

**Por qué F3/F4 dejaron de abortar.** Abortar como los demás los convertía en un interruptor de apagado accesible desde cualquier cuenta: `profile-photo-upload-url` no tiene cuota, así que subir 501 objetos sin confirmar bastaba para que cada pasada encontrase >500 huérfanos, abortase, y encolara cero — **y el estado es absorbente**, los huérfanos nunca bajan solos de 500. El barrido quedaba inutilizado para siempre, con él el único recolector que cumple el Art. 17.

> Regla general, aplica a cualquier cron/cola/límite, no solo a este: **un freno cuyo disparador controla el atacante no puede parar el trabajo entero — tiene que acotarlo.**

Acotar elige los objetos **más antiguos**, no los primeros del listado lexicográfico (que favorecería siempre a los UUID bajos).

## Las trampas de plataforma, verificadas contra el sistema real

- `CLOUDFLARE_R2_ENDPOINT` **no** lleva el nombre del bucket — va como parámetro aparte del SDK. Colarlo en el endpoint produce rutas duplicadas y 404 sin pista.
- Endpoint sin `.eu.` no ve los buckets EU: da **403** en las tres operaciones probadas, no `NoSuchBucket`. En el endpoint correcto, una clave inexistente da `NoSuchKey` 404 (respuesta autorizada) — si todo da 403 sin distinguir, sospechar del endpoint antes que de los permisos.
- Un token "de escritura" que en realidad no lee falla en silencio hasta que algo intenta leer — pasó con el token de R2 del Bloque 3: subía y borraba bien, y los tres primeros `HeadBucket`/`ListObjectsV2`/`GetObject` del barrido de huérfanos devolvieron `Access Denied`.

## Los 8 avatares predeterminados NO son medios

Son assets locales de Flutter, viajan en el binario. `profiles.preset_avatar` guarda un slug, no una ruta — el `check profiles_preset_avatar_valid` cierra el dominio a esos 8 valores porque "unificarlos" en R2 parece una simplificación y es una trampa: una clave compartida se borra para todos en cuanto uno cambia de avatar.

`check profiles_avatar_exclusive` impide que `photo_path` y `preset_avatar` sean ambos no nulos — un usuario tiene UN avatar.

## Lo que sigue sin cubrirse (deliberadamente, por ahora)

- Imagen válida pero maliciosa contra el decodificador del dispositivo (categoría CVE-2023-4863) — decodificar en servidor no lo resolvería.
- Moderación de contenido abusivo pero válido — eso es `report-create`, no esta skill.
- Volumen: `profile-photo-upload-url` sigue sin rate limit por cuenta.

Ver también: [[RLS-y-permisos]], [[Esquema-y-migraciones]] (tablas lápida sin FK), memoria `grasp-probar-el-camino-real-de-borrado`.
