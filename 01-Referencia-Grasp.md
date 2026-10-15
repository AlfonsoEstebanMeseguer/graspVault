# Referencia Rápida de Grasp

## Qué es Grasp

App de **salas de voz** (grupo) + **mensajería directa de texto** (1:1). Sin notas de voz — [[04-Decisiones/0006-la-mensajeria-es-solo-texto|ADR 0006]].

Ver [[01-Producto/Que-es-Grasp]] para el detalle de producto.

## Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Supabase + Edge Functions (Deno)
- **Base de datos:** PostgreSQL (RLS + policies)
- **Almacenamiento:** Cloudflare R2
- **Pagos:** RevenueCat

## Invariantes de seguridad

Leer antes de tocar cualquier dominio (se carga la skill correspondiente):

| Dominio | Skill | Regla clave | Nota del vault |
|---------|-------|------------|-----------------|
| RLS, permisos, datos privados | `rls-security` | Deny by default; SELECT y UPDATE requieren `GRANT` por columnas | [[03-Invariantes/RLS-y-permisos]] |
| Schema, migraciones | `db-schema` | Validación en el camino de escritura; contadores recalculables; sin FK desde tablas lápida | [[03-Invariantes/Esquema-y-migraciones]] |
| Edge Functions | `edge-functions` | `service_role` solo backend; validación de input; idempotencia en pagos | [[03-Invariantes/Edge-Functions-y-reglas-de-negocio]] |
| UI Flutter | `flutter-ui` | Revisar boceto en `pictures/screens/`; tokens de paleta, no hardcoded | [[03-Invariantes/UI-Flutter-y-producto]] |
| Ficheros de usuario | `media-storage` | Bytes → R2; fila → clave; cascada explícita de borrado (RGPD) | [[03-Invariantes/Ficheros-de-usuario-y-R2]] |
| Gifts, monedas, pagos | `gifts-ledger` | Invariante contable, comisión de plataforma | [[03-Invariantes/Gifts-y-pagos]] |
| Voz | `voice-service` | Contrato de la interfaz, proveedor intercambiable | [[03-Invariantes/Voz]] |

## Arquitectura por capas (Flutter)

```
features/
  ├── presentation/   (UI, widgets)
  ├── domain/         (entities, use cases)
  ├── data/           (repositories, models)
  └── core/           (servicios compartidos, helpers)
```

State management: **Riverpod**
Navegación: **go_router**

Detalle: [[02-Arquitectura/Mobile-Flutter]].

## Rutas API (Edge Functions)

Ver la tabla completa y actualizada en [[02-Arquitectura/Contratos-API]] — la lista de abajo es solo
orientativa, el filesystem real tiene más funciones de las que caben aquí.

| Función | Propósito |
|---------|-----------|
| `room-actions` | Crear/unirse a salas; escenario de anfitrión + 2 hablantes (ADR 0035), aforo 8 |
| `messaging-send` | Enviar mensajes; idempotencia |
| `gift-send` | Enviar regalos (monedas); ledger |
| `iap-webhook` | Webhook de RevenueCat; verifica compras |
| `profile-avatar-set` | Subir avatar → R2 |
| `media-gc-cron` | Borrar ficheros huérfanos |

## Orden de fases

1. **Bloque 0-3:** Setup, auth, MVP básico (Fase 1)
2. **Fase 4+:** Salas, mensajería, pagos, voz

Revisar [[01-Producto/Roadmap-de-fases]] para el estado real y `docs/Grasp-Fase1.md` para el plan operativo.

## Comandos útiles

```bash
# Backend
supabase start
supabase db push
supabase functions deploy <nombre>

# Mobile
flutter run
flutter test
flutter analyze

# Tests de Edge Functions (manual)
deno test apps/backend/supabase/functions/<nombre>/_test.ts
```

## Convenciones

- **SQL:** snake_case, migraciones con rollback
- **Timestamps:** `timestamptz` solo si alguien los lee
- **Dart:** PascalCase (clases), camelCase (variables)
- **Environment:** `.env` nunca en git; verificar con `grep -o NOMBRE_CLAVE` (nunca `cat .env`) — ver [[00-Metodo/Seguridad-higiene-de-secretos]]

## Links

- Documento maestro: `docs/Grasp-ClaudeCode-Bootstrap.md`
- Reglas del proyecto: `.claude/CLAUDE.md`
- Equipo de agentes: [[06-Agentes/Equipo-de-agentes]]
- Glosario de reglas de negocio: [[Glosario]]
- Índice general del vault: [[Home]]

---

*Vault creado el 2026-10-04 como referencia cross-projects de Grasp. Reindexado y ampliado el 2026-10-04.*
