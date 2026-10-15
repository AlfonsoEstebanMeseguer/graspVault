---
tags: [decision, grasp, media-storage, rgpd, schema]
aliases: ["ADR 0010"]
---

# 0010 — Avatares prediseñados + foto de perfil en R2 (modo dual)

ADR reescrito por completo el 2026-08-10 porque la versión original describía un sistema que nunca se construyó. Define el diseño real: `profiles.photo_path` gobierna el modo dual (prediseñado local vs foto real en R2); subida directa cliente→R2 con URL prefirmada firmada por `profile-photo-upload-url`; confirmación en dos pasos vía `profile-avatar-set`; borrado por cascada asíncrona (trigger → `storage_gc_queue` → `media-gc-cron`); lápidas sin FK (ver [[0009-avatar-photo-rgpd-audit]]); `preset_avatar` con `check` que impide guardar una ruta de R2.

Refinado por [[0012-honrar-el-mime-type-de-la-subida]], [[0013-validar-los-bytes-en-la-confirmacion]] y [[0014-el-avatar-no-estrena-pantalla]].

[Fichero original](../../docs/decisions/0010-avatar-upload-flow.md)
