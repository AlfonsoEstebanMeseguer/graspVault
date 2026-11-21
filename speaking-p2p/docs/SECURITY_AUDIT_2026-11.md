# Auditoría de seguridad — 2026-11-20

Auditoría completa de `speaking-p2p/` y de `.github/workflows/speaking-p2p*.yml` (commit base `4e0f55f`) con la skill **`cloudflare/security-audit`** (perfil *standard*). Después se repasa la checklist de 25 puntos. Sustituye como referencia a `SECURITY_AUDIT_2026-11-02.md`, que afirmaba algo que el código ya no cumple (ver C-H1).

- **Método:** 4 agentes de reconocimiento, 11 cazadores en 2 rondas, 2 críticos de cobertura, 6 verificadores de candidatos y 5 verificadores de registros, cada uno independiente de quien encontró el problema. En total, 28 agentes.
- **Ejecución:** solo SQL, dentro de un contenedor `postgres:16` sin red, en solo lectura y con límites de CPU y memoria, cargado con las migraciones reales y usuarios ficticios. No se ejecutó Deno, Flutter, LiveKit ni R2, y no se tocó nada desplegado.
- **Artefactos de la skill** (no se versionan; contienen evidencias): `C:\Users\alfon\security-audit-skill\graspVault\run-1\`. Ahí están `REPORT.md`, `NEEDS-VALIDATION.md`, `findings.json` (validado), `coverage-ledger.json` (validado) y las salidas SQL capturadas.

## 1. Resumen ejecutivo

1. **No hay nada crítico ni alto confirmado.** RLS en las 26 tablas, permisos por columna, funciones `svc_*` inaccesibles para el cliente, webhooks y token del cron que fallan cerrados, sin inyección SQL y sin secretos en el historial de git (comprobado con gitleaks).
2. **El mayor riesgo económico estaba activo en producción** (comprobado y cerrado a mano el 2026-11-21): los flags `dev_instant_rooms` y `dev_session_skip` se crean **activados** en las migraciones. Si siguen así en producción, cualquiera crea sesiones y grabaciones ilimitadas (coste en LiveKit y R2) y salta partes del examen (C1, C2). **Esto no se ha cambiado en el código, por decisión tuya:** compruébalo a mano (§4).
3. **Faltaban límites por usuario en todo** (punto 12) y **la subida de avatares no limitaba ni el tipo ni el tamaño** (C6). Ambas cosas están corregidas en esta rama.

## 2. Hallazgos

Los estados posibles son: **corregido** (en esta rama, con test), **pendiente** (necesita una acción tuya o desplegar) y **N/A**.

| ID | Veredicto | Sev. | Qué pasa | Estado |
|---|---|---|---|---|
| C1 | **confirmado en producción** | media | `enter_now` (flag `dev_instant_rooms`, activado al crearse) crea sesiones ilimitadas sin elegibilidad ni ventana horaria: 20 salas con grabación por usuario en el sandbox. El 2026-11-21 el flag estaba a `true` en producción | **cerrado a mano 2026-11-21** (flag a `false`) |
| C2 | **confirmado en producción** | baja | `skip` (flag `dev_session_skip`, activado al crearse) deja que cualquier participante salte segmentos, aunque eso es exclusivo del líder Pro. El 2026-11-21 el flag estaba a `true` en producción | **cerrado a mano 2026-11-21** (flag a `false`) |
| C3 | confirmado | baja | `report_user` aceptaba el chat de otra pareja y lo retenía más allá de los 30 días | corregido `8913df3` |
| C4 | por validar | — | Al reconectar con un token antiguo de LiveKit no se volvía a aplicar el permiso de micro | corregido `e2a5057` (re-push) |
| C5 | rechazado | — | Carrera entre ticks concurrentes: falla del lado seguro y no da ventaja a nadie | — |
| C6 | por validar | — | La URL de subida del avatar firmaba solo `host` (aws4fetch ignora `content-type` y `content-length` sin `allHeaders`) | corregido `f41ad0e` |
| C7 | por validar | — | La app descargaba y decodificaba el avatar ajeno sin límite (posible cuelgue por memoria) | corregido `f41ad0e` |
| C8 | por validar | — | Los avatares subidos y nunca confirmados no se borraban nunca | corregido `f41ad0e` |
| C9 | confirmado | baja | Un denunciado que borra su cuenta antes del baneo vuelve con el mismo email | corregido `8913df3` |
| C10 | por validar | — | `account-delete` se conformaba con un token refrescado (`iat`) | corregido `bd0da02` (`amr`) |
| C11 | por validar | — | Con el registro por email sin confirmación, se puede quemar la prueba o banear el email de otra persona | **pendiente (tú)** |
| C12 | por validar | — | Carrera: una grabación podía reclamarse en una sesión ya abortada por un borrado de cuenta | corregido `bd0da02` |
| C13 | por validar | — | Cada `tick` sobre una sesión cerrada llamaba a `DeleteRoom` de LiveKit, sin límite | corregido `bd0da02` |
| C14 | confirmado | baja | Un usuario bloqueado podía revivir y modificar una reunión en curso con quien lo bloqueó | corregido `23b004f` |
| C15 | confirmado | baja | Un ausente podía reprogramar una reunión ya empezada y así evitar el no-show | corregido `23b004f` |
| C-H1 | endurecimiento | — | El webhook de LiveKit compara la firma con `!==`, no en tiempo constante; además `exp` es opcional y no hay protección contra replay. Sin el secreto no es explotable | pendiente |

Los detalles completos, con trazas `archivo:línea`, reproducción y planes de validación, están en los artefactos de la skill (`REPORT.md` y `NEEDS-VALIDATION.md`).

## 3. Checklist (puntos 1–25)

| # | Punto | Estado | Nota |
|---|---|---|---|
| 1 | Autenticación sólida | ✅ con matices | JWT verificado en servidor (`auth.getUser`). Se corrigió C10. Pendiente tuyo: confirmación de email (C11) y protección de contraseñas filtradas (§4). |
| 2 | Claves fuera / historial / vault | ✅ | gitleaks sobre todo el historial: solo claves públicas por diseño (publishable key, IDs OAuth, DSN de Sentry, clave `phc_` de PostHog). `.env` y `key.properties` nunca se subieron. Se dejó de versionar la caché de wrangler (`d3e926b`). |
| 3 | BD protegida (SQLi, RLS…) | ✅ | Advisors de Supabase: solo avisos esperados (14 tablas deny-all a propósito, 11 RPC documentadas). |
| 4 | HTTPS forzado | ✅ | ATS activo en iOS y sin cleartext en Android. `Env.assertSafe` exige https. |
| 5 | Contraseñas con hash | N/A | Lo hace GoTrue (bcrypt). Activa la protección de contraseñas filtradas. |
| 6 | Validación en servidor | ✅ | zod en todas las funciones, más CHECKs y validaciones en SQL. Mejorable: el cuerpo del webhook de RevenueCat. |
| 7 | XSS | N/A | Flutter muestra el texto como `Text`. Sin WebViews y sin web desplegada. |
| 8 | Registrar actividad rara | ⚠️ | Sentry y PostHog existen, pero no hay alertas. Recomendado: alerta de gasto (punto 20) y de picos de 429. |
| 9 | Rutas de administración | ✅/⚠️ | No hay panel: se modera desde el editor SQL. Las "puertas traseras" reales son los flags de desarrollo (C1, C2). |
| 10 | Consultas parametrizadas | ✅ | `EXECUTE` solo en migraciones y sobre constantes. Filtros de PostgREST parametrizados. |
| 11 | Variables de entorno | ✅ | Solo nombres en `.env.example`. La app rechaza claves de servicio al arrancar. |
| 12 | Rate limiting | ✅ **nuevo** | `svc_rate_hit` en todas las funciones autenticadas (`e2a5057`). |
| 13 | CORS | N/A | `*` es aceptable: la auth va por Bearer, no por cookie, y la app no tiene origen web. |
| 14 | Cabeceras de seguridad | N/A | Es una API JSON sin web. Se revisará si algún día se publica la versión web. |
| 15 | Cookies | N/A | No se usan. La sesión queda ahora excluida de las copias de seguridad de Android (`d3e926b`). |
| 16 | CSRF | N/A | Con auth Bearer no aplica. |
| 17 | Caducidad de enlaces | ✅ | URLs firmadas: subida 300 s, avatar 300 s, grabación 3600 s, contenido 7200 s. No hay enlaces mágicos. |
| 18 | Subidas: tamaño y tipo | ✅ **corregido** | C6, C7 y C8 (`f41ad0e`). |
| 19 | Depuración apagada | ⚠️ | En la app, todo va detrás de `kDebugMode`. En el servidor siguen los flags C1 y C2 → §4. |
| 20 | Costes imprevisibles | ⚠️ | El límite por usuario y C13 ya están corregidos. Falta poner topes y alertas de gasto en los paneles (§4). |
| 21 | Dependencias al día | ✅ | supabase-js de las funciones pasa de 2.45.4 a 2.119.2 (`abab10d`). `flutter pub upgrade` (`9210dd2`): 147 tests pasan. |
| 22 | Paquetes inútiles | ✅ | Todas las dependencias directas se usan. Fuera los `.pyc` versionados. |
| 23 | Archivos expuestos | ✅ | Ya no se versionan `wrangler-account.json` (ID de cuenta y tu nombre) ni los `__pycache__`. |
| 24 | Revocar secretos | ✅ nada que revocar | No se filtró ningún secreto real. Ver §4.4 sobre el historial. |
| 25 | Front ofuscado / sin source maps | ✅ | Los releases usan `--obfuscate --split-debug-info`, sin source maps. |

## 4. Acciones manuales (por urgencia)

1. ~~**Flags de desarrollo en producción (C1, C2).**~~ **Hecho el 2026-11-21:** estaban a `true` y se pusieron a `false`. Para revisarlo de nuevo, en el editor SQL de Supabase:
   `select key, value from public.app_config order by key;`
   Si `dev_instant_rooms` o `dev_session_skip` valen `true`:
   `update public.app_config set value = 'false' where key in ('dev_instant_rooms','dev_session_skip');`
   (`assume_paid` se queda en `true` a propósito, D-067.)
2. **Aplicar las migraciones y desplegar las funciones** de esta rama. Hazlo primero en un entorno de pruebas si lo tienes: son 3 migraciones `20261120*` y **las 11 Edge Functions** (todas, porque cambia el código compartido de `_shared/`).
   - Después publica la app, porque **la versión anterior ya no puede subir foto de perfil** (ahora se exige `sizeBytes`).
   - Prueba en un dispositivo `livekit_client` 2.14, que trae una dependencia nativa nueva.
   - En pruebas, comprueba que un token refrescado sigue conservando `amr` (C10). Si no fuera así, `account-delete` pediría reautenticarse siempre, que falla del lado seguro.
3. **Supabase → Authentication:**
   - Activa **Confirm email**, o limita el registro por contraseña a la cuenta demo de App Review (C11).
   - Activa **Leaked password protection** (advisor).
   - Activa **Realtime › solo canales privados** (endurecimiento).
4. **Historial público:** `wrangler-account.json` sigue en commits antiguos. No es una credencial (solo el ID de cuenta y tu nombre), así que **no hace falta revocar nada** ni reescribir el historial. Si aun así quieres borrarlo, se haría con `git filter-repo`, y eso exige un *force push*: avísame antes.
5. **Topes y alertas de gasto:**
   - **LiveKit Cloud:** límite de minutos y de egress.
   - **Cloudflare:** alertas de facturación de R2.
   - **Supabase:** *spend cap* activado.
   - **OpenAI:** límite mensual en la cuenta.
6. **R2:** con el nuevo GC ya no hace falta una regla de ciclo de vida en `speaking-media`. Comprueba que `speaking-recordings` mantiene su regla de 30 días.
7. **GitHub:** asocia los workflows de release a un *environment* protegido con revisión obligatoria (endurecimiento).

## 5. Qué no se ha podido verificar

- **El comportamiento real de LiveKit** (C4, C13): no se ejecutó nada contra LiveKit. C4 se mitiga con un re-push; la mitigación completa sería emitir los tokens con `canPublish=false`.
- **La aceptación de cabeceras firmadas por R2** (C6): sigue la semántica estándar de S3 y está cubierta con un test de firma. Conviene confirmarlo con una subida real en pruebas.
- **El valor de los flags y la configuración de Auth en producción** (C1, C2, C11): el sistema de permisos bloqueó la lectura en producción. Lo tienes en §4.1 y §4.3.
- **La app Flutter en un dispositivo**: se ejecutaron `flutter analyze` y `flutter test`, pero ningún build nativo.
