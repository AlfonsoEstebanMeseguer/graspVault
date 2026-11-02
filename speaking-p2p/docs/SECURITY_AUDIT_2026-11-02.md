# Auditoría de seguridad — 2026-11-02

Revisión estática del código + introspección de privilegios reales en el proyecto Supabase de
producción (`hlkiplxfegzboupimczu`), más la skill de revisión de seguridad. Alcance: inyección SQL,
RLS y fugas de datos, autorización de las Edge Functions y RPC, webhooks, y almacenamiento R2
(Cloudflare). **No** se hicieron pruebas destructivas ni ataques de denegación sostenidos.

## Veredicto

No encontré una forma sólida de romper la aplicación. El backend está, de hecho, bien diseñado:
la identidad siempre sale de un JWT verificado en servidor, las funciones privilegiadas no son
accesibles desde el cliente, los webhooks verifican firma en tiempo constante y el almacenamiento
está acotado por el servidor. Lo que sigue son endurecimientos menores, no agujeros.

## Qué se comprobó y por qué aguanta

### Autorización e identidad
- `requireAuthUser` **verifica** el JWT contra Supabase Auth (`auth.getUser`), no lo decodifica sin
  más. La identidad del actor es siempre `user.id` del token; el cuerpo de la petición solo lleva el
  `sessionId`/acción. Un cliente no puede suplantar a otro usuario.
- Las Edge Functions comprueban pertenencia antes de actuar (p. ej. `session-actions` exige que el
  llamante sea `user_a` o `user_b` de la sesión).
- El token de LiveKit se firma en servidor con `canPublish` tomado del estado del micro calculado por
  el servidor (`tick`). Un participante no puede concederse voz cuando le toca estar en silencio, ni
  entrar en la sala de otra sesión (la sala es el `sessionId`).

### Funciones SQL (`SECURITY DEFINER`)
- Introspección en producción: **ninguna** función `svc_*` ni del esquema `private` es ejecutable por
  los roles `authenticated` o `anon`. Solo las llama el `service_role` desde las Edge Functions, ya
  con el JWT verificado. Esto cierra el riesgo mayor (que un cliente invocara
  `svc_session_presence(p_user => otro)` directamente).
- Las 10 RPC que sí son llamables por el cliente (`block_user`, `unblock_user`, `is_blocked_with`,
  `report_user`, `rate_partner`, `companion_add`, `companion_remove`, `my_companions`,
  `offer_taken_slots`, `live_activity`) derivan el actor de `auth.uid()` **dentro** de la función
  (el parámetro `p_user`/`p_other` es siempre el *objetivo*, nunca el actor) y fijan
  `set search_path = ''`, lo que neutraliza el ataque clásico de secuestro de esquema contra
  funciones `SECURITY DEFINER`.
- El advisor marca esas 10 como «ejecutables por usuarios»: es **esperado y correcto**, autorizan
  bien. No es una vulnerabilidad.

### Inyección SQL
- No hay SQL dinámico con datos del usuario. El único `EXECUTE format(...)` usa `%I` sobre una lista
  de nombres de tabla **fija y codificada** (para activar RLS y revocar permisos en bucle), no sobre
  entrada externa.
- Las entradas se validan con Zod en las Edge Functions y con `CHECK`/enums en las funciones SQL
  (códigos `bad_reason`, `bad_level`, `bad_kind`, `bad_stats`, etc.).

### RLS y datos privados
- `profiles_private` (fecha de nacimiento, teléfono, email): RLS activa, lectura y escritura acotadas
  a `id = auth.uid()`. Ningún usuario lee los datos privados de otro.
- `push_tokens`: RLS activa; lectura, inserción y borrado acotados a `user_id = auth.uid()`. No se
  pueden borrar ni leer tokens ajenos.
- `profiles`: lectura pública (es el perfil público), escritura solo de la fila propia. Los datos
  públicos se exponen además por la vista `public_profiles`.
- Las 10 tablas que el advisor marca como «RLS activa sin política» (p. ej. `user_reports`,
  `match_queue`, `exam_catalog`, `revenuecat_events`) son **deny-all a propósito**: solo se tocan vía
  `service_role`/funciones. Es la opción segura. Confirmado que no tienen grants directos al cliente.

### Webhooks
- `revenuecat-webhook`: compara el `Authorization` contra el SHA-256 del secreto en **tiempo
  constante** y **falla cerrado** si el secreto no está configurado. Un atacante no puede falsificar
  un evento para concederse una suscripción.
- `livekit-webhook`: verifica la firma del cuerpo con el secreto de LiveKit antes de procesar.

### Almacenamiento R2 (Cloudflare)
- Subida de avatar: el **servidor** elige la clave `avatars/{user.id}/{uuid}.ext`; el cliente no
  elige la ruta (sin *path traversal*, sin sobrescribir ficheros de otros) y la firma fija el
  `Content-Type`.
- URLs de visualización: las grabaciones comprueban que el llamante sea participante y que no hayan
  caducado; las claves de «contenido» (audio/foto de examen) se limitan con una expresión regular
  estricta. Los avatares son datos públicos por diseño.

## Endurecimientos recomendados (menores)

1. **Activar la protección de contraseñas filtradas** (HaveIBeenPwned) en Supabase Auth. Hoy está
   desactivada (WARN del advisor). Aplica si se usa alta con email/contraseña.
   Panel: Authentication → Policies. (https://supabase.com/docs/guides/auth/password-security)
2. **Límite de frecuencia (rate limiting)** en las Edge Functions de abuso barato: `matchmaking`,
   `report_user`, `session-actions:talk_stats`. Hoy dependen de los límites de plataforma de
   Supabase. Un usuario autenticado podría hacer *spam*. No rompe nada, pero conviene antes de crecer.
3. **CORS `Access-Control-Allow-Origin: *`**: es aceptable aquí porque la autenticación va por
   `Bearer` (no por cookie), así que no hay CSRF. Si algún día se usan cookies, habría que restringir
   el origen.
4. Revisar la región de datos de LiveKit y Cloudflare R2 (ver `docs/legal/ASPECTOS_A_COMPLETAR.md`,
   punto 10): es cumplimiento, no seguridad técnica.

## No aplica

- *Buffer overflows*: la pila es Dart / TypeScript (Deno) / PostgreSQL gestionado; no hay memoria
  manual que desbordar.
- Manipulación del *bundle* local: el contenido de examen que viaja en la app es JSON firmado en CI;
  manipularlo en un dispositivo solo afecta a ese dispositivo y el servidor es la autoridad del
  estado de la sesión.
