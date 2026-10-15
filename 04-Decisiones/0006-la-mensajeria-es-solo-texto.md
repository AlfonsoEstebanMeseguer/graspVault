---
tags: [decision, grasp, producto, mensajeria]
aliases: ["ADR 0006", "sin notas de voz"]
---

# 0006 — La mensajería de Grasp es solo texto: no hay notas de voz

Decisión de producto del usuario (2026-08-28) que **invierte** la decisión original del mismo número (2026-08-06, que preveía notas de voz en Fase 4). `direct_messages` no lleva `kind`, `audio_path`, duración ni tamaño.

No afecta a la voz del producto (salas en directo, llamadas privadas vía `VoiceService`/LiveKit — tiempo real, no se almacena) (el buffer de audio del botón de pánico que se preveía para la Fase 10 se descartó: [[0043-moderacion-con-revision-humana|ADR 0043]]).

**Por qué pesa tanto**: evita la superficie de moderación más cara (audio = revisión humana + retención excepcional al Art. 17 RGPD), un segundo bucket de R2 sin reconciliación, dos Edge Functions más, y un problema de accesibilidad.

[Fichero original](../../docs/decisions/0006-la-mensajeria-es-solo-texto.md)
