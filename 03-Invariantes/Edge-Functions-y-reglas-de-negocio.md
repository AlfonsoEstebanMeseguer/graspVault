---
tags: [invariante, grasp, edge-functions, backend]
---

# Edge Functions y reglas de negocio

> Skill origen: `.claude/skills/edge-functions/SKILL.md`. Relacionada con [[RLS-y-permisos]] y [[Esquema-y-migraciones]].

## Lo no negociable

- `service_role key` solo server-side, nunca embebida en Flutter.
- Validación de input obligatoria antes de tocar la BD.
- Idempotencia en `gift-send`, `messaging-send`, `iap-webhook` (clave por evento).
- Reglas de negocio críticas (anfitrión + 2 hablantes, saldo diario de voz, minutos free de llamada, saldo de monedas) se validan en backend, nunca solo en cliente.
- Pagos y VIP pospuestos ([[0042-pagos-y-vip-se-posponen-hasta-validar|ADR 0042]]): `gift-send` e `iap-webhook` siguen siendo solo `README.md`, pero la regla de idempotencia les aplica el día que existan.
- Ficheros de usuario nunca por el body: la función emite URLs firmadas — ver [[Ficheros-de-usuario-y-R2]].

## Una acción irreversible se REAUTENTICA — el JWT no basta

Un JWT solo prueba que hubo login durante su vigencia; quien coge un móvil desbloqueado tiene uno válido. Pesa el doble en Grasp porque el alta no tiene verificación de correo (ADR 0005) — no hay segundo factor de reserva.

Patrón: contraseña **ahora** + frase de confirmación, **las dos comprobadas en backend**. Una frase validada solo en la UI se la salta un `curl` con el JWT robado. Precedente: `account-delete`, ADR [[04-Decisiones/0016-borrado-de-cuenta-con-reautenticacion\|0016]].

## Una mutación que no produce `FAILED` no está probada

Al mutar código para comprobar que un test muerde, no basta con buscar líneas `FAILED` en la salida: **hay mutaciones que no fallan, revientan** (OOM, cuelgue, timeout) y no dejan ninguna línea.

Precedente: quitar el guardia de búsqueda vacía de `findMatches` dejó `indexOf("")` en bucle infinito acumulando hasta 4GB — "Fatal JavaScript out of memory". Cero líneas `FAILED`, y el detector lo leyó como "no rompe nada": lo contrario de la verdad.

| Lo que se ve | Qué significa |
|---|---|
| Líneas `FAILED` | La mutación muerde (caso normal) |
| Sin `FAILED`, exit 0 | No rompe nada de verdad — falta un test |
| Sin `FAILED`, crash/OOM/timeout | Muerde **tanto** que no hay informe |

Acotar con `timeout` cualquier mutación que meta un bucle. Ver memoria `grasp-una-mutacion-que-revienta-no-falla`.

## Un RPC que lee `auth.uid()` NO se llama con `service_role` — y no da error

La clave de servicio es un JWT sin `sub`, así que `auth.uid()` es `NULL` dentro. El RPC no falla: **devuelve la respuesta del anónimo**, que suele parecer plausible (todo `false`, todo vacío).

Precedente: `activity_status(uuid[])` llamado con `service_role` devolvía `false` para todo el mundo — la bandeja habría pintado todos los puntos en gris, para siempre, sin una línea en los logs.

Regla: si la función lee `auth.uid()`, se llama con el cliente del usuario (`requireAuthUser` ya da uno). Se detecta provocando el caso contrario: un `false` correcto y uno roto son el mismo byte.

## Un campo que la UI no pinta pero que varía es un oráculo regalado

Si la respuesta tiene estados y en alguno ciertos campos no se usan, esos campos se emiten **constantes** — si su valor depende de algo secreto, lo delata sin que nadie lo note, justo porque nadie lo mira.

Precedente: en la fila 4 de `messaging-thread` (solicitud recibida sin aceptar) la UI sustituye el input por acciones y no pinta `can_send`/`input_notice`/`messages_left` — pero salían del veredicto, y para esa fila `can_send: false` **solo** podía venir de un bloqueo. Fuga alcanzable: A manda solicitud a B, A bloquea a B, B abre el hilo. ADR [[04-Decisiones/0025-la-fila-4-del-input-se-emite-constante\|0025]].

Se arregla en lo que se **pinta**, nunca en lo que se **permite** — igualar el veredicto deja pasar la acción prohibida.

## Antes de verificar una regla: ¿contra qué control, y hay datos para el caso malo?

Cuatro trampas reales detectadas auditando el §12 de la Fase 4:

1. **Verificar lo contrario de lo que el sistema promete** — comprobar que el ADR no enmendó la regla antes de escribir el criterio de aceptación.
2. **Comparar contra el control equivocado y contaminado** — "no revela nada" es una afirmación sobre DOS respuestas; nómbralas las dos y añade un envío de control.
3. **Escenario sin datos para que el caso malo sea representable** — un conjunto vacío cumple cualquier igualdad; sembrar datos con variedad real.
4. **El propio arnés vació el escenario** — un endpoint que escribe al leer (impresiones, cupos) no da el mismo resultado la quinta vez. Medir con una cuenta que no haya llamado antes.

## Un `db push` alinea el esquema, NO el código desplegado

Tras cambiar una columna, comprobar qué versión de cada función está viva con `list_edge_functions` (versión y fecha reales — única autoridad). `docs/api-contracts.md` diciendo "desplegado en producción" solo afirma que **hubo** un despliegue en algún momento.

Precedente (2026-08-23): cuatro funciones llevaban meses con código viejo en producción — `profile-update` seguía escribiendo una columna ya borrada, `media-reconcile-cron` abortaba en vez de acotar (regresión de H-S-03), y `account-delete` no estaba desplegada en absoluto. ADR [[04-Decisiones/0019-reconciliar-produccion-sin-reconstruirla\|0019]].

## Un permiso que vive en un sistema externo no se retira cambiando la base

Un token emitido sigue valiendo hasta que se revoca **allí**. Lo que sube permisos va base → externo; lo que los baja, externo → base; y la reconciliación solo quita. Así un fallo a medias deja menos permiso del debido, nunca más. Precedente: el `canPublish` de LiveKit, [[0033-voiceservice-no-decide-quien-habla|ADR 0033]] y [[Voz]].

## Toda función HTTP corta el preflight CORS antes de mirar la sesión (punto 15)

Un `OPTIONS` no lleva `Authorization`: sin el corte cae en `requireAuthUser`, da 401 y el navegador aborta. El POST nunca sale y el cliente lo traduce a «no hay conexión», culpando a la red. **Solo falla en web**, así que el móvil no lo delata. Lo guarda `_shared/cors_test.ts`, que tuvo que ampliarse: comprobar que la función *llama* al corte no basta, hay que comprobar que *devuelve* su respuesta.

## El fixture de una API externa se copia de una respuesta REAL (punto 16)

Un test escrito con la forma que supones prueba tu suposición. El de LiveKit asumía camelCase; la API responde `can_publish`, y la reconciliación de voz no retiró ningún permiso en producción con la suite en verde. Lo destapó el arnés con dispositivos reales (`apps/backend/scripts/voice-e2e/`).

## Dos ficheros `.env`, no uno

El runtime de Edge Functions (Deno) lee `apps/backend/supabase/functions/.env`, no el `.env` de la raíz. Ponerla en el fichero equivocado falla igual que si la variable no existiera. `docker restart` **no relee ninguno de los dos** — hace falta `stop`/`start` del stack completo.

Ver también: [[RLS-y-permisos]] (mismo patrón "un valor correcto y uno roto son el mismo byte"), memoria `grasp-una-mutacion-que-revienta-no-falla`.
