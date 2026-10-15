---
tags: [decision, grasp, ui, producto]
aliases: ["ADR 0014"]
---

# 0014 — El avatar no estrena pantalla: es una hoja modal sobre `08-profile.jpeg`

No existe boceto de selección/subida de avatar, y CLAUDE.md exige preguntar antes de improvisar diseño. El usuario delegó la decisión: se usa una hoja modal inferior reutilizando el patrón ya existente (`ProfileEditSheet`) en vez de crear una pantalla nueva con ruta en `go_router` — no es "improvisar diseño" porque reutiliza patrones ya aprobados.

**Corrección posterior**: se había descrito una tercera acción "Quitar la foto" que el contrato no soporta (`parseAvatarRequest` exige exactamente uno de `photo_path`/`preset`) — no se añade, porque elegir un dibujo ya cumple esa función (ver [[0010-avatar-upload-flow]]).

[Fichero original](../../docs/decisions/0014-el-avatar-no-estrena-pantalla.md)
