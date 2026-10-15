---
tags: [decision, grasp, rgpd, media-storage]
aliases: ["ADR 0009"]
---

# 0009 — RGPD audit log para fotos de perfil

`photo_audit_log` registra cada upload/delete de foto de perfil por obligación legal (Art. 6.1.c), no consentimiento, con retención de 90 días.

**Corrección del 2026-08-10**: la FK original a `auth.users` con `ON DELETE RESTRICT` pretendía "preservar" el registro y en realidad **bloqueaba el borrado de cuenta entero** — nadie con una foto subida podía borrar su cuenta. Se retira la FK: la tabla es una lápida y no referencia lo que entierra. Precedente central del invariante "una tabla lápida no lleva FK contra lo que entierra" (`db-schema`, punto 4b).

Retención de 90 días implementada vía `pg_cron`, vigilada por `ops-digest-cron`.

[Fichero original](../../docs/decisions/0009-avatar-photo-rgpd-audit.md)
