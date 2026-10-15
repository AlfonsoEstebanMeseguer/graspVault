---
tags:
  - arquitectura
  - grasp
  - moc
---

# Index — Arquitectura

Mapa de las notas de arquitectura técnica de Grasp. Empezar por [[Vision-general]].

| Nota | Qué cubre |
|---|---|
| [[Vision-general]] | Diagrama de flujo completo Flutter ↔ Edge Functions ↔ Postgres/RLS ↔ R2/RevenueCat |
| [[Backend-Supabase-Edge-Functions]] | Deno, lista real de Edge Functions, convenciones, idempotencia |
| [[Mobile-Flutter]] | Arquitectura por capas, Riverpod, go_router, features reales |
| [[Base-de-datos-Postgres]] | Convenciones SQL, patrones recurrentes de RLS/GRANT, squash de migraciones |
| [[Contratos-API]] | Tabla de Edge Functions reales → propósito → estado de despliegue |
| [[Almacenamiento-R2-y-voz]] | Cloudflare R2 (ficheros de usuario) y VoiceService (LiveKit) |

## Relación con otras carpetas del vault

- Los invariantes de seguridad que sostienen esta arquitectura (RLS+GRANT, validación en el camino de
  escritura, tokens internos, etc.) viven con su precedente completo en `03-Invariantes/`.
- Las decisiones puntuales que dieron forma a piezas concretas (ADR 0010 avatar, ADR 0032 feed de
  salas, ADR 0021 sin confirmación de lectura…) viven en `04-Decisiones/`.

## Ver también

- [[Que-es-Grasp]]
- [[Roadmap-de-fases]]
