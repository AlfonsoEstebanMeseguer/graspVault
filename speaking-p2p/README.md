# Speaking P2P

App móvil para simular por parejas el examen oral tipo Cambridge (B1, B2, C1): un examinador pregrabado marca turnos y tiempos, los micrófonos los abre y cierra el servidor, y al final los dos se dan feedback.

| | |
|---|---|
| Contrato del proyecto | [CLAUDE.md](CLAUDE.md) |
| Decisiones | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Estado | [docs/PROGRESS.md](docs/PROGRESS.md) |
| Crítica y riesgos | [docs/REVIEW.md](docs/REVIEW.md) |
| Patrones del vault | [docs/VAULT_NOTES.md](docs/VAULT_NOTES.md) |
| Servicios a configurar | [docs/SETUP.md](docs/SETUP.md) |
| Diseño: pantallas → comportamiento → backend | [docs/design/SCREENS.md](docs/design/SCREENS.md) |

```
content/                  exámenes y diagramas (JSON, fuente de verdad) + fixtures
scripts/content/          validar, derivar campos, sincronizar catálogo y app
apps/backend/supabase/    migraciones, Edge Functions (Deno), tests SQL
apps/mobile/              app Flutter (Riverpod, go_router, ARB ES/EN)
```

Al cambiar contenido: `fill-derived.ts` → `validate.ts` → `golden.ts` (si cambia la línea temporal) → `sync-catalog.ts` → `sync-app.ts`. El CI falla si alguna copia queda vieja.
