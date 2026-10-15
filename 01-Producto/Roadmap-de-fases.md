---
tags:
  - producto
  - grasp
  - roadmap
---

# Roadmap de fases

> [!warning] No avanzar de bloque/fase sin cumplir su Definition of Done
> Regla explícita de [[Como-trabaja-Alfonso|cómo se trabaja en este proyecto]]: cada bloque tiene un DoD
> verificable (no solo "está implementado", sino "se comprobó contra un entorno real"), y no se pasa al
> siguiente sin cerrarlo. Fuente operativa: `docs/Grasp-Fase1.md`.

## Orden de fases

| Fase | Contenido | Estado (verificado contra docs/BLOQUE*-STATUS.md y Grasp-Fase1.md) |
|---|---|---|
| **Bloque 0** | Entorno, dependencias, MCPs/plugins, cuentas (Supabase, LiveKit, RevenueCat) | ✅ Cerrado |
| **Bloque 1** | Supabase + Auth (email/contraseña, sin login social, sin verificación) + frontend inicial | ✅ Cerrado 2026-08-08 |
| **Bloque 2** | Onboarding + motor de emparejamiento (scoring puro, **sin UI de feed** — [[0007-bloque2-sin-ui-de-feed\|ADR 0007]]) | ✅ Cerrado |
| **Bloque 3** | Perfil (métricas, edición, foto/avatar, seguidores, racha) | ✅ Backend completo y verificado contra R2 real; UI de avatar hecha (P5) |
| **Fase 4** | Mensajería directa 1:1 de texto, Contactos, Conectar, bloqueo, reporte mínimo | ✅ Desplegada en producción el 2026-08-28 |
| **Fase 5** | Salas (esquema, RLS, ciclo de vida, chat de sala, lista por actividad — [[0032-el-feed-de-salas-no-se-personaliza\|ADR 0032]]) | ✅ Cerrada 2026-10-05, cron verificado en producción |
| **Fase 6** | Voz real con LiveKit; el servidor da y quita la palabra ([[0033-voiceservice-no-decide-quien-habla\|0033]], [[0035-escenario-anfitrion-mas-dos-hablantes\|0035]]) | ✅ En producción 2026-10-06, probada en móvil real |
| **Fase 7** | Llamadas privadas 1:1 con cupo diario cortado por el servidor ([[0039-una-llamada-silencia-la-sala-sin-sacarte\|0039]]) | ✅ Verificada en producción 2026-10-07/08 |
| **Topes de voz** | Saldo diario de 30 min + anuncios con recompensa; salas de 8 ([[0041-tope-diario-de-minutos-en-salas\|0041]]) | ✅ En producción 2026-10-11 — falta ver el anuncio de prueba (espera la aprobación de AdMob) |
| **Fase 9a** | VIP sin cobro, dado a mano con un comando | ✅ En producción 2026-10-12 |
| **Fase 10a** | Moderación con revisión humana, modo restringido, pánico sin audio, edad mínima 18 ([[0043-moderacion-con-revision-humana\|0043]], [[0044-edad-minima-18\|0044]]) | ✅ Cerrada 2026-10-13 |
| **Fase 10b** | Detección automática (clasificador que llena la cola) | pendiente — antes o después del lanzamiento, se decide en su spec |
| **Fase 13** | Analytics (PostHog, Sentry) — adelantada | **siguiente** |
| **Fase 12 recortada** | Push y anuncios con recompensa, sin interstitial | pendiente |
| **Fase 14** | Testing y hardening + la CI que sigue sin existir | pendiente |
| **Lanzamiento** | Privacidad, ficha, beta cerrada, cuenta de Play con test de 14 días; cambiar `applicationId` | pendiente |
| **Tras validar** | Fase 8 (gifts y pagos), 9b (cobro de VIP), 11 (gamificación), interstitial | pospuestas — [[0042-pagos-y-vip-se-posponen-hasta-validar\|ADR 0042]] |

> [!info] Orden reescrito el 2026-10-11
> Tras la Fase 7 el orden dejó de seguir la numeración: va por **riesgo** (coste de la voz, usuarios
> vulnerables) y por lo que hace falta para decidir (analytics antes que pagos). Fuente:
> [[0042-pagos-y-vip-se-posponen-hasta-validar|ADR 0042]] y la § 8 del documento maestro.

## Por qué el Bloque 2 no tiene UI de feed

Decisión deliberada ([[0007-bloque2-sin-ui-de-feed|ADR 0007]]): en ese punto del proyecto un perfil sugerido no tenía ninguna acción
posible (seguir llega en el Bloque 3, mensajería en la Fase 4) y las salas no existían hasta la Fase 5.
Se construyó el **motor** (scoring puro, con tests) sin construir una pantalla que no serviría para nada
todavía. Tres tiempos de reutilización del mismo scoring:

| Cuándo | Qué |
|---|---|
| Bloque 2 | El scoring, función pura probada. Sin UI. |
| Bloque 3 | `connect-feed` sobre perfiles + pantalla de sugeridos ("seguir"). |
| Fase 5 (descartado) | Aplicar el mismo scoring a salas — **revertido por el [[0032-el-feed-de-salas-no-se-personaliza|ADR 0032]]**: el feed de salas no se personaliza. |

## Lectura importante sobre los documentos de estado

> [!warning] Las fotos de estado caducan
> `docs/BLOQUE1-STATUS.md` y `docs/BLOQUE2-STATUS.md` son **instantáneas de su fecha de cierre**, no el
> estado de hoy — cada uno lleva en cabecera la lista de lo que ya no es cierto. La fuente de verdad del
> estado real siempre es: `docs/Grasp-Fase1.md` (bloque/fase en curso), `docs/db-schema.md` (esquema real)
> y `docs/api-contracts.md` (contratos reales, con columna "Estado" que distingue desplegado/pendiente/
> planificado). Este mismo patrón — "un documento histórico que ya no describe el sistema, dejado vivo a
> propósito con un aviso en cabecera" — se repite en todo `docs/` y es importante no confundirlo con
> documentación caducada por descuido.

## Cómo se cierra una fase desde la Fase 5

Cada fase de voz se cerró con una **prueba de dos dispositivos reales** contra producción, además de la
suite: el móvil real destapó fallos que ningún doble de test podía ver (reconectar es «caerse» para el
webhook de LiveKit, la API responde en `snake_case`). Los arneses viven en `apps/backend/scripts/voice-e2e/`
y `calls-e2e/`. Lo pendiente de cada fase está en su spec (`docs/superpowers/specs/`) y en
`docs/pending-messaging.md` para la Fase 4.

## Ver también

- [[Que-es-Grasp]]
- [[Vision-general]]
- [[Como-trabaja-Alfonso]]
