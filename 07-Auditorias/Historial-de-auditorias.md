---
tags: [auditoria, grasp]
aliases: [Audits, Historial E2E]
---

# Historial de auditorías de Grasp

Cronología de `docs/audits/`. Casi todas las de ficha suelta (anteriores al 2026-08-16) llevan hoy una cabecera **"Estado: histórico"** añadida por `context-curator`: el documento se conserva entero como prueba de qué se comprobó esa fecha, pero no describe el sistema actual. Esa cabecera en sí es el patrón a imitar — ver [[Roadmap-de-fases#Lectura importante sobre los documentos de estado|«las fotos de estado caducan»]].

| Fecha | Documento | Qué se auditó | Resultado / hallazgo principal |
|---|---|---|---|
| 2026-08-08 | [`2026-08-08-bloque1-audit.md`](../../docs/audits/2026-08-08-bloque1-audit.md) | Cierre Bloque 1 (auth, schema, RLS, rate limiting, tokens de diseño) | GO-WITH-CAVEATS. Firmado por el propio orquestador, no por `reviewer-agent`/`security-agent` — lección de método capturada en memoria de `audit-leader` |
| 2026-08-10 | [`2026-08-10-bloque3-e2e-audit.md`](../../docs/audits/2026-08-10-bloque3-e2e-audit.md) | E2E avatares y foto de perfil | Prueba de que la cascada de borrado RGPD llegó a estar rota y cómo se detectó |
| 2026-08-10 | [`2026-08-10-reconciliacion-huerfanos-e2e.md`](../../docs/audits/2026-08-10-reconciliacion-huerfanos-e2e.md) | Reconciliación de huérfanos en R2 | El barrido solo abre un bucket (hallazgo `R-01`) — ver [[Ficheros-de-usuario-y-R2|`media-storage`]] |
| 2026-08-12 | [`2026-08-12-servir-foto-de-perfil-e2e.md`](../../docs/audits/2026-08-12-servir-foto-de-perfil-e2e.md) | Servir foto de perfil | Bytes idénticos, caducidad real de 300s, fallo cerrado verificado |
| 2026-08-13 | [`2026-08-13-avatar-preset-e2e.md`](../../docs/audits/2026-08-13-avatar-preset-e2e.md) | Avatar predeterminado y borrado de foto | Camino "tenía foto → elijo predeterminado → se borra de R2" confirmado, por API sin UI |
| 2026-08-13 | [`2026-08-13-p0-despliegue-y-e2e-produccion.md`](../../docs/audits/2026-08-13-p0-despliegue-y-e2e-produccion.md) | Despliegue de imágenes de perfil + E2E en PRODUCCIÓN | Primer E2E real contra producción del proyecto |
| 2026-08-15 | [`2026-08-15-auditoria-integral/`](../../docs/audits/2026-08-15-auditoria-integral/) (00–07 + V01–V07) | Auditoría integral de todo el proyecto, corte Fase 1→Fase 4 | GO-WITH-CAVEATS. Primera pasada con 3 hallazgos refutados y 5 matizados en segunda opinión (V01-V07). Hallazgos más graves: nadie podía borrar su cuenta (`H-SV-02`) → [[0016-borrado-de-cuenta-con-reautenticacion|0016]]; `Content-Type` elegido por el cliente (`H-SV-01`); nadie validaba la edad (`H-RV-01`) |
| 2026-08-16 | [`2026-08-16-equivalencia-antes-despues/`](../../docs/audits/2026-08-16-equivalencia-antes-despues/) (00-veredicto + focos) | ¿El refactor (squash de 19→3 migraciones + compactación de docs) preservó los resultados de la auditoría integral? | EQUIVALENTE CON PÉRDIDAS MENORES (3 advertencias operativas no bloqueantes). Auditoría declarada **incompleta**: `audit-leader` murió por límite de sesión antes de consolidar |
| 2026-08-28 | [`2026-08-28-contactos-y-mensajeria-e2e.md`](../../docs/audits/2026-08-28-contactos-y-mensajeria-e2e.md) | E2E Contactos y mensajería (Fase 4, §12 spec) en local | Checklist recorrido con HTTP real + psql; pendiente despliegue a producción |
| 2026-08-28 | [`2026-08-28-humo-en-produccion-fase4.md`](../../docs/audits/2026-08-28-humo-en-produccion-fase4.md) | Humo de la mitad "texto" de Fase 4 en PRODUCCIÓN | Confirmación en backend desplegado real, con cuentas creadas/borradas |
| 2026-08-30 | [`2026-08-30-connect-muestreo-e2e.md`](../../docs/audits/2026-08-30-connect-muestreo-e2e.md) | Muestreo del feed de Conectar movido a SQL | Punto 16 de `pending-messaging.md` reescrito, no cerrado del todo |
| 2026-08-30 | [`2026-08-30-desbloqueo-e2e.md`](../../docs/audits/2026-08-30-desbloqueo-e2e.md) | Desbloquear, en PRODUCCIÓN | Cierra puntos 2 y 3 de `pending-messaging.md` bajo [[0027-el-bloqueo-deja-de-ser-irreversible|0027]] |
| 2026-08-30 | [`2026-08-30-tope-tag-lookup-y-vigilancia-del-pool-e2e.md`](../../docs/audits/2026-08-30-tope-tag-lookup-y-vigilancia-del-pool-e2e.md) | Tope de búsquedas por tag + vigilancia del pool de Conectar, en PRODUCCIÓN | Cierra [[0028-el-bloqueo-es-detectable-por-quien-lo-sufre|0028]] §5 y [[0030-el-tope-del-pool-de-conectar-se-vigila-en-vez-de-adivinarse|0030]] |

## Patrón transversal

Casi toda auditoría posterior al Bloque 1 distingue explícitamente **local** (stack `supabase start`) de **producción** (proyecto `epmjveozxrwuocusvyay`), y el humo en producción crea cuentas reales con `signup` que se borran al terminar con `account-delete` — la propia auditoría es la prueba de vida de ese mecanismo. Ver [[0016-borrado-de-cuenta-con-reautenticacion|0016]].

## Ver también

- [[Equipo-de-agentes]] — quién ejecuta estas auditorías (`audit-leader`, `reviewer-agent`, `security-agent`, `qa-agent`)
- [[Patron-de-memoria-de-agentes]]
