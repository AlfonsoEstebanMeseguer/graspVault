---
tags: [decision, grasp, media-storage, seguridad, edge-functions]
aliases: ["ADR 0013"]
---

# 0013 — Validar los bytes en la confirmación, por cabecera y sin decodificar

El backend nunca veía los bytes subidos (subida directa cliente→R2). Se decide validar en `profile-avatar-set`: `GET` del objeto, comprobar magic bytes (WebP/JPEG) coincidentes con la extensión, y dimensiones leídas de cabecera sin decodificar — decodificar la imagen entera no protege (una imagen maliciosa contra un decodificador decodifica bien) y añade la misma superficie que pretende cerrar.

Se borra el código muerto `_shared/image-validation.ts` (dependía de `imagescript`, documentaba mal lo que hacía). Deja fisura conocida: la URL de subida admite un segundo `PUT` tras la validación (mitigado, no cerrado).

[Fichero original](../../docs/decisions/0013-validar-los-bytes-en-la-confirmacion.md)
