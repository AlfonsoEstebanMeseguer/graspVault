---
tags: [decision, grasp, producto, seguridad, mensajeria]
aliases: ["ADR 0022"]
---

# 0022 — Un solo texto para el input inerte

Choque entre dos reglas de la spec: `RN-21` exige explicar cuál límite se alcanzó y cuándo se recupera; `RN-23` exige que el bloqueo nunca se revele y que su texto sea byte a byte igual al de "cupo agotado". Ambas no pueden cumplirse a la vez con frases distintas-pero-iguales.

**Decisión del usuario**: ambos casos (cupo agotado y bloqueo) muestran el mismo texto de `RN-21` ("Podrás seguir escribiendo cuando esta persona acepte tu mensaje"); se sacrifica la literalidad de `RN-23` pero no lo que protege (ninguna palabra "bloqueo", cuerpos idénticos). Precedente de la serie de ADRs sobre canales laterales de mensajería junto a [[0025-la-fila-4-del-input-se-emite-constante]] y [[0027-el-bloqueo-deja-de-ser-irreversible]].

[Fichero original](../../docs/decisions/0022-un-solo-texto-para-el-input-inerte.md)
