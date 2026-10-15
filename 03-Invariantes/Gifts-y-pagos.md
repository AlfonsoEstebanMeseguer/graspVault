---
tags: [invariante, grasp, gifts, pagos, ledger]
---

# Gifts y pagos

> Skill origen: `.claude/skills/gifts-ledger/SKILL.md`. Dominio: `coin_wallets`, `coin_purchases`, `gift_transactions`, `payouts`, función `gift-send`, webhook `iap-webhook`.

## Invariante contable

Nunca se crean monedas de la nada. Toda entrada de saldo viene de `coin_purchases` acreditada por `iap-webhook`; toda salida de `gift_transactions` registrado. La suma de balances + comisiones retenidas tiene que reconciliar contra `coin_purchases` + `gift_transactions`.

## Comisión y atomicidad

`platform_fee` se calcula con una constante configurable (nunca un número hardcodeado) y se separa explícitamente de `host_earning` en cada fila. Descuento al emisor, cálculo de comisión, acreditación al receptor e inserción en `gift_transactions` ocurren en **una única transacción SQL**.

## Idempotencia y verificación server-side

`gift-send` acepta clave de idempotencia — reintentar no duplica efectos. Nunca se acredita saldo a partir de una señal que venga solo del cliente: la verificación de compra es siempre server-side vía el webhook de RevenueCat.

## Detección de regalos circulares

Flag automático si dos cuentas se envían regalos de forma circular repetida en poco tiempo — señal de lavado de monedas o farmeo de insignias.

## Payouts

Importe mínimo, verificación de identidad, límite de frecuencia, revisión manual ante señales de riesgo. **Nunca un payout automático.**

## Copy legal

Los gifts no son pago por servicio profesional — tiene que quedar explícito en el copy, dado que Grasp es apoyo entre iguales, no terapia.

Ver también: [[Edge-Functions-y-reglas-de-negocio]] (idempotencia, reglas de negocio en servidor), [[06-Agentes/Equipo-de-agentes|payments-agent]].
