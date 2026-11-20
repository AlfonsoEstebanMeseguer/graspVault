# Prompt para la siguiente sesión (contexto vacío)

Copia desde la línea siguiente hasta el final.

---

Trabajamos en **Speaking P2P**, una app Flutter (Riverpod 3, go_router, i18n con ARB ES/EN) para practicar el Speaking de Cambridge (B1/B2/C1) por parejas. El backend es Supabase (proyecto `hlkiplxfegzboupimczu`, migraciones aplicadas con el MCP de Supabase), las llamadas van por LiveKit y los archivos por Cloudflare R2. El repositorio está en `D:\VSCODE\SpeakingApp\graspVault\speaking-p2p`. Respóndeme en español.

**Antes de tocar nada:**
1. Lee `CLAUDE.md`, `docs/DECISIONS.md` (sobre todo D-022 a D-045), `docs/PROGRESS.md` y el documento de diseño `docs/img/img_remaked/Speaking P2P — Sistema de diseño 2.0.md`.
2. El proyecto está indexado con codebase-memory (`D-VSCODE-SpeakingApp`). Usa sus herramientas (`search_graph`, `trace_path`, `get_code_snippet`) para explorar el código antes que grep.
3. Reglas del diseño: solo los tokens de `lib/core/theming/` (`palette.dart`, `tokens.dart`) y los componentes de `lib/core/ui/` (`kit.dart`, `brand.dart`, `pico.dart`). Ningún `Color(0x…)` fuera de la paleta. Todo texto por i18n. No cambies la lógica del examen ni del reloj.
4. Si algo necesita una herramienta, una IA generativa, una clave o una instalación que no puedes hacer bien tú solo, **pregúntame antes**.

**Tarea 0 · Pendiente de la sesión anterior.** La migración `apps/backend/supabase/migrations/20261024200000_report_block.sql` (reportar y bloquear, D-044) **no está aplicada** en Supabase: la ventana de confirmación caducó dos veces. Avísame justo antes de lanzarla con `apply_migration` para que la apruebe a tiempo. Después, renombra el archivo a la versión que registre Supabase (D-024) y revisa los avisos del asesor de seguridad. Su suite (`tests/sql/09_report_block.sql`) ya pasa en Docker.

**Tarea 1 · Rediseñar la Agenda para que sea más intuitiva.** Hoy son tres pestañas (Ofertas · Chats · Mi agenda) más un botón «Ofrecer horario» y una tarjeta de reunión fijada en cada chat. Archivos: `lib/features/agenda/` (`agenda_screen.dart`, `chat_screen.dart`, `create_offer_sheet.dart`, `accept_offer_sheet.dart`, `agenda_common.dart`) y `lib/domain/agenda/agenda.dart`. Empieza por recorrerla como un usuario nuevo y dime dónde se pierde. Después propón el rediseño con bocetos ASCII o capturas, **espera mi visto bueno** e impleméntalo. Las capturas se generan con `test/screenshots/screens_test.dart` (instrucciones en su cabecera).

**Tarea 2 · Revisar la lógica de la Agenda y proponer mejoras.** Critica la estructura, el diseño y la lógica actuales (ofertas con franja horaria, varios aceptantes por oferta, un chat por aceptación, confirmación doble, 30 min por reunión, aviso 10 min antes, ausencias, máximo 2 ofertas). El objetivo del producto:
- la Agenda sirve para **quedar y hablar lo justo para organizar un examen**;
- debe permitir **tener compañeros habituales («amigos») con los que repetir un examen** fácilmente;
- **no** debe convertirse en una red social (nada de feeds, perfiles extensos, chats de grupo ni mensajería libre sin una reunión detrás; para eso están otras redes).

Dame un análisis con problemas concretos, alternativas y una recomendación (por ejemplo: «repetir con la misma pareja», lista de compañeros habituales con invitación directa, chat ligado siempre a una reunión, caducidad de los chats), con su impacto en las tablas y funciones de Supabase. **No implementes la parte de backend hasta que lo apruebe.** Ten en cuenta que reportar y bloquear (D-044) debe seguir funcionando en todo lo nuevo.

**Tarea 3 · Fotos de la Parte 2.** Los exámenes hacen referencia a ids de foto (`content/photos.json` tiene la descripción de cada una). Las fotos se dejan en `content/photos/` con el nombre del id y se sincronizan con `scripts/content/sync-photos.ts`; la licencia de cada una se apunta en `content/LICENSES.md`.
- No hay ningún MCP de Google Imágenes instalado, y la mayoría de esas imágenes tienen derechos de autor: no sirven para una app de pago. Busca en bancos con licencia libre para uso comercial (Unsplash, Pexels, Pixabay o Wikimedia Commons con CC0 o CC BY) usando WebSearch y WebFetch, o propónme instalar un MCP o una API de esos bancos si hace falta una clave (pregúntame).
- Para cada foto pendiente: busca una que encaje con su descripción y con lo que pide la pregunta del examen. Las dos fotos de una pareja deben poder compararse.
- Si no encuentras ninguna que encaje, **apúntala en una lista con un prompt listo para que yo la genere con IA**: una por línea, con el id, la escena, el estilo fotográfico realista, el formato horizontal 4:3 y sin texto ni logotipos.
- Al final, dame la lista de las que has bajado (con su fuente y licencia) y la de las que me tocan a mí.

**Tarea 4 · Solo en vertical.** La app no debe girar a horizontal.
- Flutter: `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` en `main.dart`.
- Android: `android:screenOrientation="portrait"` en la actividad de `AndroidManifest.xml`.
- iOS: deja solo `UIInterfaceOrientationPortrait` en `UISupportedInterfaceOrientations` de `Info.plist`.
- iPad: Apple exige todas las orientaciones si la app admite la multitarea. Dime si prefieres añadir `UIRequiresFullScreen` o marcar la app como solo iPhone.

**Tarea 5 · Ondas del botón de búsqueda en naranja.** El botón circular «Buscar pareja» de Inicio (`lib/features/home/search_pulse.dart`) se queda exactamente como está: mismo tamaño, color cobalto, degradado, icono y texto. Lo único que cambia son las ondas que salen de él (`_Rings`): pasan a ser naranjas, con el color del candidato B (`palette.roleB`), en los dos temas. Mantén la opacidad decreciente y el respeto a «Reducir movimiento». Apúntalo como decisión de diseño en `docs/DECISIONS.md` (amplía D-043) y en la memoria del diseño. Si las ondas de la pantalla «Buscando compañero…» (`search_screen.dart`) también deben cambiar, pregúntame antes: esta decisión se refiere al botón de Inicio.

**Cómo verificar:** `flutter analyze` sin avisos; `flutter test` (hoy pasan 87); la suite SQL en Docker (comando en `docs/PROGRESS.md`, sección «Cómo se verifica hoy»); capturas en claro y oscuro de las pantallas tocadas; y al final, instalar en mi Xiaomi por adb inalámbrico (te daré la IP y el puerto). No hagas commit sin preguntarme.
