# Patrones reutilizados del vault de Grasp

> Fuente: la raíz de este mismo repositorio (`graspVault/`), que es el vault de Obsidian.
> CLAUDE.md lo espera en `docs/vault/`; ver DECISIONS D-001.
> El vault es un **resumen** del repo de Grasp, no su código: aquí se reutilizan patrones y lecciones, no ficheros.

## Stack heredado (gana el vault en técnica)

| Ámbito | Grasp | Aquí |
|---|---|---|
| App | **Flutter** + Riverpod + go_router, capas `core/ data/ domain/ features/` | Igual. CLAUDE.md caía a React Native solo "si el vault no lo deja claro": lo deja claro |
| i18n | ARB + `context.l10n`, ES/EN de fábrica (ADR 0036) | Igual desde el día 1 (en Grasp costó ~470 cadenas hacerlo tarde) |
| Tema | Tokens por **rol**, nunca por tono; `onBrand` ≠ blanco (ADR 0031) | `core/theming/palette.dart` + test de contraste **calculado** |
| Backend | Supabase + Edge Functions (Deno) | Igual, en `apps/backend/supabase` |
| Voz | LiveKit **sin SDK de servidor**: firmar JWT + API Twirp; el servidor da y quita la palabra (ADR 0033) | `_shared/livekit.ts`; `canPublish` lo decide la base, nunca el cliente |
| Ficheros | R2 con URL prefirmada; la fila guarda la clave; validar bytes con magic bytes (ADR 0010/0012/0013) | Avatares y grabaciones igual |
| Pagos | RevenueCat + webhook idempotente | Igual |
| Crons | `pg_cron` desde migración + token interno por hash (ADR 0011) | Igual (`private.invoke_worker`) |

## Invariantes que se aplican tal cual

1. **RLS filtra filas; GRANT filtra columnas.** Toda tabla nace con `revoke all` a `anon`/`authenticated` y `grant` explícito a `service_role` (que tiene BYPASSRLS, no BYPASSGRANT). Datos privados en tabla aparte (`profiles_private`) y vista `public_profiles` que **enumera** columnas.
2. **Reglas de negocio en el servidor**, en una transacción, con bloqueo (`for update` / advisory locks). El cliente solo refleja.
3. **`service_role` jamás en la app.** `Env.assertSafe()` rechaza arrancar con una service key o con la URL del panel.
4. **Funciones `security definer`**: `search_path = ''` (sin comillas), `revoke execute` de `public/anon/authenticated`.
5. **Tablas lápida sin FK** (`storage_gc_queue`, `trial_claims`): sobreviven al borrado del dueño.
6. **Borrar la fila no borra el fichero**: trigger `before delete` → cola → cron que borra en R2.
7. **El camino real del RGPD es `delete from auth.users`**, no `delete from profiles` (los tests lo usan).
8. **Acción irreversible = reautenticación** + frase comprobada en el servidor (borrado de cuenta).
9. **Preflight CORS antes de mirar la sesión** (solo falla en web, el móvil no lo delata).
10. **LiveKit**: `UpdateParticipant` reemplaza el permiso entero (mandar el conjunto completo); la API habla snake_case y los webhooks camelCase; reconectar = salir; bajar permisos primero.
11. **Realtime**: la tabla entra en `supabase_realtime` en su migración; el fallo es mudo.
12. **Un `CHECK` acota el contenido, no la ausencia**; `btrim` antes de medir longitudes.
13. **Un test que no muerde no prueba nada**: mutar el código y ver el rojo (hecho con 3 mutaciones en la suite SQL; una no mordía y se reforzó).
14. **Test de widget a tamaño de móvil** + `takeException()`; la fuente de test es más ancha (cota conservadora). Encontró dos overflows reales.
15. **Un placeholder honesto lo es en su forma**: sin botones que no hacen nada (Agenda/Perfil hoy).
16. **Ningún anuncio durante sala/llamada** → aquí: nunca en lobby, examen ni feedback.

## Método (00-Metodo)

- Cuestionar antes de implementar y dejar el desacuerdo por escrito → `docs/REVIEW.md`.
- Nunca leer ni pedir el valor de un secreto; `.env.example` con nombres; hashes para secretos compartidos.
- Recomendación razonada con **una** opción marcada; los clics exactos en paneles externos → `docs/SETUP.md`.
- "Hecho" = probado contra el entorno real y en dispositivo, no solo tests verdes (ver PROGRESS: qué falta por verificar en real).
- `git add` fichero a fichero.

## Lo que NO se hereda

- Reglas de negocio de Grasp (salas, gifts, VIP, Conectar).
- Login con email/contraseña (ADR 0003/0004/0005): aquí es **solo Google** por producto.
- Edad mínima 18 (ADR 0044): aquí el producto fija **14** (ver REVIEW, riesgo 1).
- Borrar el teléfono (ADR 0015): aquí el producto lo pide (ver REVIEW, riesgo 3).
