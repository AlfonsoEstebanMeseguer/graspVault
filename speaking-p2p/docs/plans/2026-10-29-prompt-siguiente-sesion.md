# Prompt para la siguiente sesión (contexto vacío)

Copia desde la línea siguiente hasta el final.

---

Trabajamos en **Speaking P2P**, una app Flutter (Riverpod 3, go_router, i18n con ARB ES/EN) para practicar el Speaking de Cambridge (B1/B2/C1) por parejas. El backend es Supabase (proyecto `hlkiplxfegzboupimczu`, migraciones aplicadas con el MCP de Supabase), las llamadas van por LiveKit (solo audio) y los archivos por Cloudflare R2. El repositorio es `D:\VSCODE\SpeakingApp\graspVault` (git, rama de trabajo `claude/sweet-pasteur-kebuvg`) y el proyecto está en la subcarpeta `speaking-p2p`. Respóndeme en español.

**Antes de tocar nada:**
1. Lee `speaking-p2p/CLAUDE.md`, `docs/DECISIONS.md` (sobre todo D-039 a D-047), `docs/PROGRESS.md` y el documento de diseño `docs/img/img_remaked/Speaking P2P — Sistema de diseño 2.0.md`.
2. El proyecto está indexado con codebase-memory (`D-VSCODE-SpeakingApp`). Usa `search_graph`, `trace_path` y `get_code_snippet` para explorar antes que grep.
3. Reglas de diseño: solo los tokens de `lib/core/theming/` (`palette.dart`, `tokens.dart`) y los componentes de `lib/core/ui/` (`kit.dart`, `brand.dart`, `pico.dart`). Ningún `Color(0x…)` fuera de la paleta. Todo texto por i18n. No cambies la lógica del examen ni del reloj salvo donde lo pida una tarea.
4. Si algo necesita una herramienta, una IA generativa, una clave o una instalación que no puedas hacer bien tú solo, **pregúntame antes**. Las claves van en `speaking-p2p/.env` (en `.gitignore`), **nunca** en `.env.example`. No gastes de la API de OpenAI sin preguntarme: me quedan unos 5 €.
5. No hagas commit ni push sin preguntarme.

**Tarea 1 · El examinador no suena hasta tocar el volumen.** En el móvil (lo he visto en el iPhone), al empezar el examen el audio del examinador no se oye hasta que pulso subir o bajar volumen. Debe sonar desde el primer momento, sin tocar nada.
- El lector está en `lib/features/exam/reader_player.dart` (`FileReaderPlayer`, `just_audio`), y la llamada en `lib/core/voice/livekit_engine.dart`. La app no gestiona hoy la sesión de audio (`AVAudioSession` en iOS, `AudioManager` en Android): sospecho que al conectar LiveKit la sesión queda en modo llamada con la salida en el auricular o con el volumen de «llamada» a cero, y que pulsar el volumen la reactiva. Comprueba la causa real antes de arreglarlo (paquete `audio_session`, configuración de audio de LiveKit, altavoz por defecto…).
- Requisitos: altavoz por defecto (salvo auriculares o Bluetooth), el micro sigue funcionando y el eco no empeora. Ha de funcionar en iOS y en Android, también en el modo práctica sin conexión.

**Tarea 2 · Botón naranja para crear un examen en la Agenda.** La Agenda tiene ahora dos pestañas («Mis exámenes» y «Buscar horario») y un botón «＋ Proponer» en la cabecera (`lib/features/agenda/agenda_screen.dart`). Quiero además un botón circular como el de «Buscar pareja» de Inicio (`lib/features/home/search_pulse.dart`), pero con los colores al revés: **círculo naranja (`palette.roleB`) con ondas azules (`palette.brand`)**. Al pulsarlo se abre «Proponer horario» (`create_offer_sheet.dart`) para que otros reserven. Haz `SearchPulse` configurable en color de círculo y de ondas sin cambiar cómo se ve en Inicio. Propón dónde colocarlo (por ejemplo, arriba de «Mis exámenes» o en el estado vacío) con un boceto ASCII o una captura y **espera mi visto bueno** antes de implementarlo. Respeta «Reducir movimiento».

**Tarea 3 · Parte 3: los bocadillos se superponen.** En el diagrama de la Parte 3 (`lib/features/exam/widgets/bubble_diagram.dart`) la pregunta central y los 5 prompts colapsan entre sí y no se leen. Separa más el bocadillo central del resto y reparte los cinco alrededor para que no se toquen nunca: en pantallas pequeñas, con textos largos (C1) y con el texto a 200 % (`textScaler`). Añade un test de widget que compruebe que ningún bocadillo se solapa con otro en 2 o 3 tamaños de pantalla. Capturas en claro y oscuro.

**Tarea 4 · Parte 2: separar las preguntas del enunciado.** **IMPORTANTE: los enunciados están bien, no cambies ni una palabra** (tampoco el audio ni `audioMs`). Solo cambia cómo se muestran: que las preguntas se distingan del resto, como en el cuadernillo real. Ejemplo:

```
Candidate A, your pictures show different attitudes to clothes.
Choose two of the pictures and say:
  • what these attitudes reveal about the people
  • what the consequences of their behaviour might be
```

- Los textos están en `content/exams/{nivel}/*.json` (generados desde `scripts/content/authoring/*.txt` con `scripts/content/author.ts`: no edites el JSON a mano). Se muestran en la tarjeta de papel de la Parte 2 (`lib/features/exam/exam_screen.dart`, `PaperCard`).
- Decide si conviene un campo nuevo en el contenido (por ejemplo, las preguntas separadas que genera `author.ts` y valida el esquema) o un formateo en la app, y **explícamelo antes**. Sea como sea, el texto completo debe seguir siendo idéntico al actual (añade un test que lo compruebe para los 153 exámenes) y el audio no se toca.

**Tarea 5 · Reportar y penalizar a quien sabotee el examen.** Diseña un sistema para reportar a un compañero que sabotea el examen (no habla, se burla, pone ruido, abandona a propósito, contenido ofensivo…) y para penalizarlo, con un protocolo que permita comprobar que el reporte es cierto y que no se usa para castigar a alguien injustamente.
- Parte de lo que ya existe: `report_user` y `user_reports` (D-044, con contexto `exam` y `session_id`), el bloqueo, `attendance` y los `no_show`, `peer_ratings` (D-042), los eventos de control y abandono de la sesión (`exam_sessions`, `abort_reason`, `last_control`) y la grabación opcional con consentimiento de los dos (CLAUDE.md §6, 30 días en R2).
- Quiero un análisis con:
  - qué pruebas objetivas puede guardar el servidor (quién habló y cuánto en cada turno, desconexiones, abandonos, controles del líder…);
  - cómo se verifica un reporte (automático, revisión manual, la grabación si existe);
  - la escala de penalizaciones (aviso, suspensión temporal del matchmaking, bloqueo…) y cómo se recurre;
  - protección contra reportes falsos o en venganza;
  - privacidad y RGPD (qué se guarda, cuánto tiempo y quién lo ve);
  - impacto en las tablas, las funciones y las Edge Functions de Supabase.
- **No implementes nada de backend hasta que lo apruebe.** Reportar y bloquear (D-044) debe seguir funcionando igual.

**Cómo verificar:** `flutter analyze` sin avisos y `flutter test` (hoy pasan 99); la suite SQL en Docker si tocas SQL (comando en `docs/PROGRESS.md`, sección «Cómo se verifica hoy»); capturas en claro y oscuro de las pantallas tocadas con `test/screenshots/screens_test.dart` (instrucciones en su cabecera); y para probar en el iPhone, el `.ipa` sin firmar se compila en GitHub Actions con `gh workflow run speaking-p2p-ios.yml --ref claude/sweet-pasteur-kebuvg -f ipa=true` (gasta unos 100 minutos de Actions: pregúntame antes; lo instalo yo con Sideloadly). Apunta cada decisión en `docs/DECISIONS.md` (a partir de D-048) y actualiza `docs/PROGRESS.md`.
