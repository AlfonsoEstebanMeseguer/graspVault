# App móvil (Flutter)

```bash
flutter pub get
# Contra el proyecto Supabase de desarrollo (URL y clave PUBLICABLE: públicas por diseño)
flutter run --dart-define-from-file=env/dev.json
# Sin backend: modo práctica con compañero simulado
flutter run
```

- Nunca pongas aquí una clave `service_role` / `sb_secret_…`: la app se niega a arrancar (`Env.assertSafe`).
- Práctica saltando a un punto del examen: navega a `/practice/B2?at=390800&role=B`.
- Tests: `flutter analyze && flutter test`.
