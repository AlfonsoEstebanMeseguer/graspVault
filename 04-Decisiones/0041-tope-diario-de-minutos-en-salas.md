---
tags: [decision, grasp, voz, coste]
aliases: ["ADR 0041"]
---

# 0041 — Saldo diario de voz en las salas: 30 minutos gratis, más 5 por anuncio

El cálculo de coste de las llamadas (Fase 7) destapó que **las salas no tenían tope diario por cuenta**. Un bot conectado 24/7 cuesta unos 21,60 $/mes en LiveKit, que **cobra por persona conectada, no por persona que habla**. Con pagos y VIP pospuestos ([[0042-pagos-y-vip-se-posponen-hasta-validar|ADR 0042]]), este tope pasa a ser el único freno de coste de la voz.

**Decisión** (2026-10-08, ampliada el 2026-10-11): saldo diario de **30 minutos**, más 5 por cada anuncio con recompensa (máximo 12 al día). La sala dura **el saldo que tenía el anfitrión al crearla** (máximo 90 min) en lugar de 2 h, y admite **8 personas**. Los minutos del anuncio los concede el **servidor** tras verificar la firma SSV de AdMob. Nunca se muestra un anuncio durante una sala, llamada o chat activos.

**Estado**: en producción desde el 2026-10-11. Falta ver el anuncio de prueba en un dispositivo, bloqueado hasta que se apruebe la cuenta de AdMob.

**Lo transferible**: se calcula el coste del **abuso** (un bot, no un usuario medio) antes de abrir un recurso que se paga por minuto.

[Fichero original](../../docs/decisions/0041-tope-diario-de-minutos-en-salas.md)
