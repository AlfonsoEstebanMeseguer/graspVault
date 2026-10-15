# Pantallas → comportamiento → backend

> Fuente del diseño: [`pantallas.html`](pantallas.html) (bocetos originales, abrir en el navegador),
> capturas en [`screens/`](screens/) y textos literales en [`screens-text.txt`](screens-text.txt).
> Regla del vault: **toda pantalla nueva se maqueta mirando su boceto**; si falta, se pregunta, no se inventa.
> Este documento enlaza cada pantalla con su lógica de negocio (`svc_*` en SQL), su Edge Function y su estado.

Leyenda de estado: ✅ implementada · 🟡 backend listo, pantalla pendiente · ⏸️ aplazada por decisión.

## Flujo global

```
Login ─► Onboarding (3 pasos) ─► [Paywall si no es elegible] ─► Inicio (pestañas)
Inicio ─► Buscando pareja ─(match)─► Lobby ─► Parte 1..4 ─► Feedback ─► Inicio
               └─(15 s, sin reuniones)─► "¿Agendar?" ─► Agenda › Crear reunión
Agenda: Chats · Reuniones (tablón) · Mi agenda ─► Chat con tarjeta ─► (confirmada) ─► Entrar a la sala ─► Lobby
Perfil (grabaciones 30 días) · Ajustes (tema, idioma, suscripción, cuenta)
```

## 01 Login — ✅ (con email; Google ⏸️ D-022)
- Marca, ilustración A/B, titular, chips de nivel. El botón "Continuar con Google" se sustituye por email+contraseña hasta tener OAuth.
- La frase "Al continuar aceptas…" se omite: la aceptación con versión y fecha se guarda en el paso 3 (REVIEW).
- Backend: Supabase Auth. Router: sin sesión → `/login`.

## 02–04 Onboarding — ✅
| Paso | Campos | Reglas (cliente = servidor) |
|---|---|---|
| 1 Perfil público | foto (opcional, ⏸️ selector de fotos), `@username` con "Disponible" en vivo, idiomas (ES, EN, CA, FR, IT, + Otro) | username `^[a-z0-9_.]{3,20}$`, único (`public_profiles`); ≥1 idioma ISO 639-1 |
| 2 Datos privados | fecha (día/mes/año), teléfono con prefijo, email de la cuenta (solo lectura) | ≥14 años (trigger `enforce_min_age`), E.164 |
| 3 Nivel y términos | B1/B2/C1 con duración, casilla de términos | términos obligatorios; se guarda `terms_version` + fecha |
- Backend: `onboarding-complete` → `svc_onboarding_complete` (perfil + privado + entitlements en una transacción).

## 05 Paywall — ⏸️ (RevenueCat aplazado; D-020 "todos pagan")
- "1 test de prueba disponible", beneficios, plan 8 €/mes, "Suscribirme", "Hacer mi test de prueba gratis", "Restaurar compras".
- Lógica lista: `svc_is_eligible`; el trial se consume al empezar la Parte 1 (`try_start`).

## 06 Inicio — ✅
- "Hola, `username`", selector de nivel (chip), botón grande con pulso "Buscar pareja", resumen del examen.
- **Tarjeta de próxima reunión** ("HOY 19:00 · Reunión con dani_r · C1 · La sala se abre 5 min antes · Ver"): lee `meetings` confirmadas del usuario; desde −5 min el botón pasa a "Entrar a la sala".

## 07–08 Buscando pareja — ✅
- Avatar con anillos animados, "Buscando compañero…", cronómetro de espera, consejo "MIENTRAS ESPERAS", "Cancelar búsqueda".
- Latido: `matchmaking {enqueue}` cada ~10 s (D-009). `matched` → lobby.
- A los 15 s, si `hasOpenMeeting == false`: aviso arriba "Parece que no hay nadie buscando…" [No] [Sí, agendar] (sigue buscando mientras tanto).

## 09 Lobby (máx. 5 min) — ✅ (falta probar con dos móviles reales)
- "SALA · C1 ADVANCED", "Conoceos antes de empezar", cuenta atrás "El examen empieza solo en 03:42" (`lobby_deadline`).
- Tarjetas: avatar, nombre, "Candidato A · ES, EN", estado "Sin confirmar" / "✓ Listo" (`ready_a/b`).
- Interruptor "Grabar la sesión · Solo si los dos lo activáis · dani_r: activado" (`recording_consent_a/b`).
- "✓ Material del examen descargado" (precarga → flag `preloaded`).
- Botón micro + "Estoy listo" (flag `ready`). Botón salir (abandonar).
- Backend: `session-actions {join, flag, tick, abort}`; estado por Realtime de `exam_sessions`.

## 10–13 Partes 1–4 — ✅ offline / ✅ en vivo (sin audio del lector: TTS aplazado)
- Cabecera común: barras de progreso, "PARTE n DE 4" (+ "· PREGUNTA k DE m" en la Parte 4), título, cronómetro conmutable.
- P1: tarjetas grandes, la activa resaltada, "Te toca responder a ti", tarjeta del examinador con "Ocultar texto", pie "Tu micro está abierto".
- P2: tarjetas compactas ("Hablando · 1 min" / "Silenciado"), "dani_r elige dos de estas fotos", fotos, "Pregunta del examinador", pie "Después respondes tú · 30 s".
- P3: pestañas "Discusión · 2 min / Decisión · 1 min", micros abiertos, diagrama de burbujas nativo, botón "Ver enunciado".
- P4: banner "El examinador está hablando · Micros de los dos silenciados", "Para: los dos", pie "Al terminar, los micros se abren para los dos".
- Micros: los decide el servidor (`schedule` + `canPublish`), D-003/D-018.

## 14 Abandonar — ✅
- Hoja "¿Seguro que quieres salir?", "Salir del examen" bloqueado 5 s; al otro: "Tu compañero ha salido". `session-actions {abort}`.

## 15 Feedback (5 min) — ✅
- "Examen terminado", cuenta atrás con micros abiertos, tarjetas de los dos, 3 ideas, "Grabación guardada · podréis escucharla 30 días" (si ambos consintieron), "Terminar llamada".

## 16–21 Agenda — ✅ (push ⏸️ con Firebase)
| Pantalla | Contenido | Backend |
|---|---|---|
| Chats | lista: avatar, nombre, hora, último mensaje, línea de estado de la tarjeta ("Hoy 19:00 · C1 · Confirmada ✓✓", "Falta tu confirmación", "Cerrada") | `chats`, `chat_messages`, `meetings` (RLS + Realtime) |
| Reuniones | "MIS OFERTAS · 1 DE 2" con nº de interesados; filtros nivel / "+ Incluir B2" (adyacente) / día; tarjetas de oferta con idiomas y franja, "Elegir hora" | `meeting_offers` (RLS: abiertas y no vencidas) |
| Mi agenda | tira de la semana, lista de confirmadas, "Empieza en 4 min" + "Entrar a la sala" desde −5 min | `meetings` confirmadas; `meeting-actions {enter}` |
| Crear reunión | día (Hoy/Mañana/…/Otro), franja Desde–Hasta, nivel, "Puedes tener 2 ofertas activas · te queda 1", "Publicar oferta" | `meeting-actions {create_offer}` (máx. 2, ≤7 días, ≥30 min) |
| Aceptar oferta | huecos de 30 min dentro de la franja, los que chocan con reuniones confirmadas "Ocupado", "Proponer 19:30 y abrir chat" | `meeting-actions {accept}` |
| Chat con tarjeta | cabecera con nombre e idiomas; tarjeta fijada (fecha, hora, nivel, ✓/○ de cada uno) con Modificar/Cancelar/Confirmar; mensajes de sistema; caja de texto | `meeting-actions {modify, cancel, confirm}`; mensajes por PostgREST directo |

## 22 Perfil — ✅ (reproducir grabación: pendiente de reproductor)
- Avatar, username, idiomas, "Editar perfil", "Preparando C1 Advanced", "Exámenes hechos 7" (`exam_history` completados), "GRABACIONES" con días restantes, aviso de borrado a los 30 días (`media-view-url {recording}`).

## 23–24 Ajustes — ✅ (gestión en la tienda ⏸️ RevenueCat)
- Apariencia (Claro/Oscuro/Sistema) ✅, idioma ES/EN ✅, Suscripción (plan, estado, próximo pago, "Gestionar en la tienda") ⏸️ RevenueCat, Términos/Privacidad (pendiente de textos), Cerrar sesión ✅, Eliminar cuenta ✅ (contraseña de nuevo + frase, `account-delete`, D-027).
