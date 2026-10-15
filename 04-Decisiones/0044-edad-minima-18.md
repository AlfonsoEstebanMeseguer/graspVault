---
tags: [decision, grasp, rgpd, seguridad]
aliases: ["ADR 0044"]
---

# 0044 — La edad mínima es 18 años

Diseño de la Fase 10 (2026-10-12). El alta admitía desde los **13 años**, y en España el consentimiento digital empieza a los 14 (LOPDGDD art. 7), así que la barrera ya estaba mal. Lo grave era otra cosa: en una app de salud mental con salas, llamadas y mensajes entre desconocidos, un menor queda a un mensaje de un adulto, y ninguna moderación posterior compensa ese riesgo.

**Decisión**: **18 años**, validado en los **dos** caminos que escriben `birth_date` (el trigger `handle_new_user` y `profile-update`; punto 4d de `db-schema`) y también en el formulario. No había cuentas de menores en ningún entorno: la migración **aborta** si encuentra alguna, en vez de construir una pantalla y un cron que no tendrían uso.

**Descartado**: 16 años, porque obligaría a separar menores y adultos en todo el producto.

**Lo transferible**: una regla de validación se aplica en todos los caminos por los que nace una fila, no solo en el que se está tocando.

[Fichero original](../../docs/decisions/0044-edad-minima-18.md)
