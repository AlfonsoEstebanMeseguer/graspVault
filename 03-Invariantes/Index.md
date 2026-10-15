---
tags: [invariante, grasp, moc]
---

# Index — Invariantes de seguridad y producto

Cada nota sintetiza una skill de `.claude/skills/` con sus precedentes reales (qué falló, cuándo, qué consulta lo demuestra). La regla vive siempre en `.claude/CLAUDE.md`; aquí vive la historia que la justifica.

| Dominio | Nota | La regla más importante |
|---|---|---|
| Permisos y datos personales | [[RLS-y-permisos]] | RLS filtra filas; `GRANT` filtra columnas y verbos — hacen falta las dos capas, auditadas rol por rol (`anon`, `authenticated`, `service_role`) |
| Esquema y migraciones | [[Esquema-y-migraciones]] | Una tabla lápida nunca lleva FK contra lo que entierra; un contador no derivable va en la misma transacción que su causa |
| Backend y reglas de negocio | [[Edge-Functions-y-reglas-de-negocio]] | Una acción irreversible se reautentica; una mutación que no produce `FAILED` puede haber reventado, no "no romper nada" |
| Ficheros de usuario y R2 | [[Ficheros-de-usuario-y-R2]] | RLS protege la fila, nunca el objeto; un freno cuyo disparador controla el atacante tiene que acotar, no abortar |
| UI Flutter y producto | [[UI-Flutter-y-producto]] | Un placeholder honesto lo es también en su forma; los tokens de color se nombran por rol, nunca por tono |
| Gifts y pagos | [[Gifts-y-pagos]] | Nunca se crean monedas de la nada; nunca un payout automático |
| Voz | [[Voz]] | Ninguna pantalla importa el SDK del proveedor directamente — todo pasa por `VoiceService` |

## Principio transversal que atraviesa casi todas

> Una regla escrita en un documento se puede confundir con el estado real del sistema. No lo es. Se verifica contra la base de datos (`information_schema`), el código desplegado (`list_edge_functions`), o el sistema real (R2, el emulador) — nunca contra lo que dice el `.md`.

Ver también: [[05-Skills-de-proceso/Index|Skills de proceso]], [[04-Decisiones/Index|Decisiones (ADRs)]].
