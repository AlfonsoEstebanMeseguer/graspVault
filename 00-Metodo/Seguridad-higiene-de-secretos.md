---
tags:
  - metodo
  - grasp
  - seguridad
aliases:
  - Higiene de secretos
---

# Seguridad: higiene de secretos

> [!warning] Regla central
> **Nunca leer ni pedir el *valor* de un secreto.** Ni con `cat .env`, ni pidiéndoselo al usuario por chat.
> Para comprobar configuración, se listan solo los **nombres** de las claves. Esto es transferible a
> cualquier proyecto con `.env`, Supabase, Postgres local o cualquier panel con credenciales.

## Por qué esta regla existe (no es paranoia abstracta)

- **Leer un secreto lo mete en el transcript de la sesión**, que vive en disco y puede sincronizarse o
  acabar en logs. Da igual que el secreto en sí sea de desarrollo — el hábito es lo que importa, porque el
  mismo comando contra un proyecto real sí devuelve secretos reales.
- Alfonso ha pegado claves secretas en el chat **más de una vez**. Una de ellas acabó dentro de un fichero
  versionado del repo (`docs/ANALISIS-PROFUNDO-BLOQUE0-1-2.md`), presente desde el commit inicial y borrada
  del árbol después — pero seguía en el historial de git. **Borrar el fichero del árbol no lo saca del
  historial**, y acotar un escaneo (`git log -S`) a los commits nuevos no lo encuentra: hay que escanear
  siempre con `--all`.

## Comandos concretos que filtran secretos sin avisar

Estos son ejemplos de Grasp, pero el patrón — "el comando de diagnóstico más obvio incumple la regla por
defecto" — se repite en casi cualquier CLI de infraestructura:

- `supabase status` **sin** `-o env` imprime un JSON completo con `ANON_KEY`, `SERVICE_ROLE_KEY`,
  `SECRET_KEY` y `JWT_SECRET` tal cual. La forma correcta, cuando de verdad hace falta la clave para un
  `curl`:
  ```bash
  supabase status -o env | grep '^ANON_KEY=' > archivo_temporal.sh
  source archivo_temporal.sh     # se usa $ANON_KEY, nunca se imprime
  ```
  Para solo comprobar si el stack está levantado, `docker info` basta y no toca ninguna clave.
- Comprobar configuración de `.env` se hace con `grep -o "^NOMBRE_CLAVE_[A-Z_]*" .env` (solo nombres),
  nunca `cat .env`.
- Editar líneas **no secretas** de `.env` (endpoints, nombres de bucket, IDs de cuenta) sí es correcto —
  la regla es sobre valores secretos, no sobre el fichero entero.

## El patrón del hash en vez de copiar a mano

Cuando dos sistemas tienen que compartir un secreto para comprobar "¿el que llama lo conoce?", **el
verificador guarda solo el hash (SHA-256)** y el secreto se genera donde vive — nunca se pide al usuario
que lo copie de un panel a otro.

Precedente (2026-08-10, despliegue del Bloque 3): se pidió la `service_role key` de producción con
plantillas tipo `<pega aquí la clave>`. Salieron tres pegados malos seguidos — uno con los corchetes
dentro, otro con el prefijo de la plantilla pegado al JWT, otro con la clave equivocada — y en uno de los
intentos la clave acabó dentro de un fichero del repositorio y en el transcript del chat. Encima resultó
imposible de rotar porque Supabase había retirado la rotación de claves legacy para ese proyecto. Cada
ronda de copiado es una oportunidad de filtrarla, y el diseño original la exigía cada vez.

> [!tip] Corolario
> No ates la autenticación a una variable cuyo **contenido** decide la plataforma. `SUPABASE_SERVICE_ROLE_KEY`
> cambió de formato sola (JWT legacy → `sb_secret_…`) y tumbó un cron sin que nadie tocara el código. Si
> hace falta un secreto propio para un cron o webhook interno, se genera uno dedicado (patrón
> `requireInternalCaller`: la base de datos lo guarda en Vault, el verificador solo conoce su hash) en vez
> de reusar una credencial de plataforma.

## Herramientas que no están donde se esperan (entorno real de Alfonso)

No es higiene de secretos exactamente, pero es la misma categoría de "verificar antes de asumir":
`psql` no está en el `PATH` en esta máquina (Windows + Git Bash); el SQL de verificación se ejecuta con
`docker exec -i <contenedor_db> psql -U postgres -d postgres -v ON_ERROR_STOP=1 < fichero.sql`. Y
`adb`/herramientas del SDK de Android tampoco están en el `PATH` — viven bajo la ruta del SDK. El patrón
general: en este entorno, **nunca asumir que un binario Unix habitual está en el `PATH`**; comprobarlo
primero con un comando barato (`which`, `command -v`).

## Cómo se transporta a otro proyecto

1. Nunca pedir el valor de un secreto por chat; pedir solo dónde está, o su nombre de variable.
2. Antes de ejecutar un comando de diagnóstico de una CLI de infraestructura nueva, comprobar si tiene una
   bandera de "solo nombres" o "formato filtrable" — asumir que el modo por defecto es ruidoso.
3. Si dos sistemas necesitan validar un secreto compartido, diseñarlo como hash-only desde el principio.
4. Escanear secretos históricos siempre sobre todo el historial (`--all`), nunca acotado a "los commits de
   esta sesión".

[[Como-trabaja-Alfonso]] · [[Memoria-persistente-y-verificacion]]
