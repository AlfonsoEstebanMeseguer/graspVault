---
tags: [decision, grasp, index]
aliases: ["Index-ADRs", "Decisiones"]
---

# Índice de decisiones (ADRs)

43 decisiones (0001–0044; no existe el 0002). Actualizado el 2026-10-13. Agrupadas por dominio. El estado "aceptada/implementada/superada" vive en cada nota y en el fichero original — no se repite dos veces, siguiendo la convención de `docs/decisions/README.md`.

## Auth y acceso

| # | Título | Gist | Nota |
|---|---|---|---|
| 0001 | Frontend del Bloque 1 | Login/Registro/Start derivados de un boceto único; OTP+social al inicio | [[0001-frontend-bloque1-auth]] |
| 0003 | Migración OTP → contraseña | Se cambia a email/teléfono + contraseña | [[0003-password-auth-migration]] |
| 0004 | Sin login social | Se elimina Google/Apple Sign-In por coste y riesgo de MVP | [[0004-sin-login-social]] |
| 0005 | Registro sin email | Sin confirmación de correo; el alta abre sesión directamente | [[0005-registro-sin-email]] |

## RLS, permisos y RGPD

| # | Título | Gist | Nota |
|---|---|---|---|
| 0008 | Insignias/experiencias y grants de columna | `user_experiences` privada (Art. 9); grants de columna en `profiles` | [[0008-insignias-experiencias-y-grants-de-columna]] |
| 0009 | Audit log de fotos (RGPD) | Retención 90 días; lápida sin FK | [[0009-avatar-photo-rgpd-audit]] |
| 0015 | Borrar el teléfono | Columna filtrada a toda la base; se borra, no se esconde | [[0015-borrar-el-telefono-en-vez-de-esconderlo]] |
| 0016 | Borrado de cuenta con reautenticación | `account-delete`: JWT + contraseña + frase | [[0016-borrado-de-cuenta-con-reautenticacion]] |
| 0020 | Conectar sin datos del Art. 9 | Scoring server-side; ningún dato sensible viaja al cliente | [[0020-conectar-no-muestra-datos-del-articulo-9]] |
| 0026 | La edad es pública | Vista `public_profiles` que enumera, nunca abre RLS | [[0026-la-edad-es-publica]] |
| 0037 | El perfil ajeno se ve como el propio | `public_profiles` gana `xp` y `rooms_joined_count`; mismos widgets | [[0037-el-perfil-ajeno-se-ve-como-el-propio]] |
| 0038 | `profiles` se lee por columnas | Se cierra el `grant select` de tabla; `language` y `photo_url` se borran | [[0038-profiles-se-lee-por-columnas]] |
| 0044 | Edad mínima 18 | En los dos caminos de escritura; la migración aborta si hay menores | [[0044-edad-minima-18]] |

## Esquema, migraciones y producción

| # | Título | Gist | Nota |
|---|---|---|---|
| 0017 | Consolidar 19 migraciones en 3 | Squash con prueba de equivalencia por diff | [[0017-consolidar-las-migraciones-en-tres]] |
| 0018 | `display_name` obligatorio | Tres caminos de escritura cerrados a la vez | [[0018-display-name-obligatorio]] |
| 0019 | Reconciliar producción sin reconstruirla | Producción llevaba meses sin converger con el repo | [[0019-reconciliar-produccion-sin-reconstruirla]] |
| 0030 | Tope del pool de Conectar se vigila | `MAX_POOL` fijo + vigilancia por digest | [[0030-el-tope-del-pool-de-conectar-se-vigila-en-vez-de-adivinarse]] |
| 0034 | `apply_migration` con canonización | Permitido si el fichero local se renombra al `version` registrado en el mismo turno | [[0034-apply-migration-permitido-con-canonizacion]] |

## Voz, salas y llamadas (Fases 5–7)

| # | Título | Gist | Nota |
|---|---|---|---|
| 0033 | `VoiceService` no decide quién habla | Sube permisos base → LiveKit; baja LiveKit → base; la reconciliación solo quita | [[0033-voiceservice-no-decide-quien-habla]] |
| 0035 | Anfitrión + 2 hablantes | `room_max_speakers()` = 3 contando al anfitrión | [[0035-escenario-anfitrion-mas-dos-hablantes]] |
| 0039 | Una llamada silencia la sala | Suena aunque estés en sala; no te saca de ella | [[0039-una-llamada-silencia-la-sala-sin-sacarte]] |
| 0041 | Saldo diario de voz | 30 min + 5 por anuncio; la sala dura el saldo del anfitrión; 8 personas | [[0041-tope-diario-de-minutos-en-salas]] |

## Roadmap y moderación

| # | Título | Gist | Nota |
|---|---|---|---|
| 0042 | Pagos y VIP se posponen | Fases 8, 9b y 11 tras validar; orden nuevo hasta el lanzamiento | [[0042-pagos-y-vip-se-posponen-hasta-validar]] |
| 0043 | Moderación con revisión humana | Una máquina detecta, una persona sanciona; sin reputación ni audio | [[0043-moderacion-con-revision-humana]] |

## Media storage (avatares/fotos)

| # | Título | Gist | Nota |
|---|---|---|---|
| 0010 | Avatar upload flow (modo dual) | Rediseño completo: preset local vs foto en R2 | [[0010-avatar-upload-flow]] |
| 0011 | Token dedicado para crons internos | Hash en vez de `service_role key` | [[0011-token-dedicado-para-crons-internos]] |
| 0012 | Honrar el `mime_type` | WebP+JPEG, nunca declarar y firmar otra cosa | [[0012-honrar-el-mime-type-de-la-subida]] |
| 0013 | Validar bytes en la confirmación | Magic bytes sin decodificar | [[0013-validar-los-bytes-en-la-confirmacion]] |
| 0014 | El avatar no estrena pantalla | Hoja modal sobre el perfil existente | [[0014-el-avatar-no-estrena-pantalla]] |

## Mensajería y Conectar (Fase 4)

| # | Título | Gist | Nota |
|---|---|---|---|
| 0006 | Mensajería solo texto | Se invierte: sin notas de voz, nunca | [[0006-la-mensajeria-es-solo-texto]] |
| 0021 | Sin confirmación de lectura | `read_at` no existe; contador por fila propia | [[0021-mensajeria-sin-confirmacion-de-lectura]] |
| 0022 | Un solo texto para el input inerte | Cupo agotado y bloqueo comparten texto | [[0022-un-solo-texto-para-el-input-inerte]] |
| 0023 | El ignorar sobrevive a mensajes pendientes | `ignored` no se revierte por entrega | [[0023-el-ignorar-sobrevive-a-los-mensajes-pendientes]] |
| 0024 | Relajar el filtro solo cambia pesos | El conjunto de elegibles nunca cambia | [[0024-relajar-el-filtro-de-conectar-solo-cambia-los-pesos]] |
| 0025 | Fila 4 del input se emite constante | Cierra el oráculo pasivo de bloqueo | [[0025-la-fila-4-del-input-se-emite-constante]] |
| 0027 | El bloqueo deja de ser irreversible | `block-remove` + enmienda a RN-23 | [[0027-el-bloqueo-deja-de-ser-irreversible]] |
| 0028 | El bloqueo es detectable por quien lo sufre | Oráculo activo no se cierra; rate limit de tags | [[0028-el-bloqueo-es-detectable-por-quien-lo-sufre]] |
| 0029 | Cancelar solicitud no existe | Decisión documental: se retira del diagrama | [[0029-cancelar-una-solicitud-enviada-no-existe]] |

## Producto, matching y UI

| # | Título | Gist | Nota |
|---|---|---|---|
| 0007 | Bloque 2 sin UI de feed | Motor de scoring puro, sin pantalla todavía | [[0007-bloque2-sin-ui-de-feed]] |
| 0031 | Modo oscuro con paleta por rol | Tokens por rol, no por tono; `onBrand` ≠ blanco | [[0031-modo-oscuro-con-paleta-por-rol]] |
| 0032 | El feed de salas no se personaliza | Lista única ordenada por actividad reciente | [[0032-el-feed-de-salas-no-se-personaliza]] |
| 0036 | Español e inglés | ARB + `context.l10n`; backend traducido por `slug`; inglés de fábrica | [[0036-la-app-en-espanol-e-ingles]] |
| 0040 | Solicitudes en morado | Burbuja «+N» morada; la roja no cambia; bandeja que se relee | [[0040-las-solicitudes-se-ven-en-morado]] |

---

Volver a [[Home]].
