---
tags:
  - arquitectura
  - frontend
  - flutter
  - grasp
---

# Mobile — Flutter

Código en `apps/mobile/lib/`. Arquitectura por capas:

```
core/        # servicios compartidos: config, router, theming, ui, util
data/        # repositorios, implementaciones Supabase
domain/      # entidades, interfaces de repositorio, casos de uso
features/    # una carpeta por feature, con sus propias application/presentation
```

- **State management**: Riverpod (`NotifierProvider` para controllers).
- **Navegación**: `go_router`, con `StatefulShellRoute` para mantener el estado de las pestañas.
- **Theming**: tokens de paleta por **rol** (nunca `Color(0xFFxxxxxx)` hardcodeado ni `AppColors.x`
  directo desde una feature) — ver [[UI-Flutter-y-producto]].

## Features reales (carpetas existentes en `lib/features/`, verificado por Glob)

```
auth/  calls/  connect/  gamification/  gifts/  legal/  messages/  messaging/  moderation/
navigation/  notifications/  onboarding/  profile/  rooms/  settings/  vip/
```

16 features. Algunas (gifts, vip, calls, gamification, notifications) tienen carpeta ya creada como
andamiaje de fases futuras (Fase 8-10), igual que las Edge Functions con solo `README.md` — no asumir
que la carpeta implica funcionalidad implementada; cruzar contra [[Roadmap-de-fases]] y
`docs/BLOQUE*-STATUS.md`/`docs/Grasp-Fase1.md` para el estado real.

## `core/`

```
config/    # Env.assertConfigured — rechaza arrancar con una service_role key o URL de panel colada
router/    # go_router + redirección por sesión
theming/   # paleta mapeada a ThemeData/ColorScheme, tokens de rol
ui/        # widgets compartidos (ej. GraspBottomNav)
util/
```

`core/config/env.dart` es el primer invariante de seguridad del cliente: el arranque **falla a
propósito** si `SUPABASE_ANON_KEY` resulta ser una `service_role key` (prefijo `sb_secret_` o JWT con
`role: service_role`), o si `SUPABASE_URL` apunta al panel en vez de al API. Cubierto por test unitario.

## Convenciones de testing de UI

Un test de widget corre a **800×600** (más ancho que cualquier móvil) con fuente de *fallback*
(`google_fonts` no descarga nada en test) y recoge overflow con `tester.takeException()` — sirve como
cota conservadora, nunca para decidir sobre truncado real (eso se mira en el emulador Android; iOS no
es construible desde Windows). Detalle y precedente: [[UI-Flutter-y-producto]].

## Ver también

- [[Vision-general]]
- [[UI-Flutter-y-producto]]
- [[Roadmap-de-fases]]
