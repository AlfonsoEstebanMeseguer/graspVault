---
tags: [decision, grasp, media-storage, edge-functions]
aliases: ["ADR 0012"]
---

# 0012 — Honrar el `mime_type` de la subida, y reducir a WebP y JPEG

`profile-photo-upload-url` validaba `mime_type` y luego lo descartaba (firmaba siempre WebP), causando `SignatureDoesNotMatch` en R2 cuando el cliente declaraba otro formato. Se decide honrar el formato declarado y reducir el conjunto admitido de `{webp, jpeg, png}` a `{webp, jpeg}` — porque algunos dispositivos no pueden codificar WebP (`flutter_image_compress` puede lanzar `UnsupportedError`), y sin fallback JPEG esos usuarios no podrían subir foto en absoluto.

Decisión delegada explícitamente por el usuario. Precede y es requisito de [[0013-validar-los-bytes-en-la-confirmacion]].

[Fichero original](../../docs/decisions/0012-honrar-el-mime-type-de-la-subida.md)
