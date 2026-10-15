---
tags: [invariante, grasp, flutter, ui, design-system]
---

# UI Flutter y producto

> Skills origen: `.claude/skills/flutter-ui/SKILL.md` + `.claude/skills/design-system/SKILL.md`.

## Arquitectura (flutter-ui)

Capas: `core/` (config, DI, router, theming, `VoiceService`) → `data/` (cliente Supabase, repos, DTOs) → `domain/` (entidades, casos de uso) → `features/<dominio>/`. Una pantalla nunca llama al cliente Supabase directo. State: Riverpod. Router: `go_router`.

El cliente **nunca decide** saldo, entitlements VIP, ni máximo de hablantes — solo refleja estado que confirma backend.

## Un placeholder honesto lo es también en su FORMA

Un modal que dice «esto no hace nada» no puede ofrecer dos botones (Cancelar + Aceptar) — elegir entre dos botones afirma, por la sola disposición, que uno de los dos hace algo. Precedente: el modal del botón de pánico tenía el texto correcto y aun así dos botones. Se detectó **mirando el emulador**, no con tests — los tests comprobaban texto y ausencia de llamada a repository, y ambas cosas seguían siendo ciertas con los dos botones puestos.

Corolario para tests: cuando lo prometido es "esto no hace nada", comprobar texto + efecto **no basta** — hay que afirmar sobre los *affordances* (cuántos botones, cuál es destructivo).

## Un ajuste que se escribe y no lee nadie es un botón que miente

Es el principio "un mecanismo sin puerta de entrada" por el otro lado: aquí había entrada (escritura) y faltaba salida (lectura). Precedente: el toggle de notificaciones persistía de verdad con `set_notifications`, pero ningún endpoint lo devolvía — la campana se habría abierto siempre en "activadas".

Al auditar un ajuste, dos preguntas: quién lo escribe, y **quién lo lee, desde qué pantalla**. Antes de inventar un endpoint nuevo para leerlo, comprobar si el `GRANT` que hace falta ya está concedido contra `information_schema` — no la migración (ver [[RLS-y-permisos]]).

## Un test de widget no ve un overflow de móvil

Tres razones que se combinan y dejaron pasar un overflow real en el emulador durante todo el Bloque 2:

1. La superficie por defecto de un test es 800×600, más ancha que cualquier móvil — fijar el tamaño del Pixel 5 antes de montar.
2. Un overflow no tumba el test por sí solo (Flutter lo guarda como excepción silenciosa) — hay que `expect(tester.takeException(), isNull)`.
3. `google_fonts` no descarga nada en tests — el texto se mide con una fuente de fallback más ancha. Un test de layout es una **cota conservadora**, nunca decide sobre truncado real (eso va al emulador).

El arreglo no siempre es el obvio: medir antes de ajustar (`debugPrint` de `size.height`/`didExceedMaxLines`) reveló que el texto no entraba en dos líneas por mucho alto que se le diera — el fix real fue `maxLines: 3`, no un ajuste de un píxel.

## Tokens de color: por ROL, nunca por tono (ADR 0031)

`AppColors.purple700` describe un tono; con dos temas (claro/oscuro) eso es falso la mitad del tiempo. Una feature consume `context.palette.<rol>` (`brand`, `onBrand`, `textPrimary`, etc.), nunca `AppColors.x` ni `Color(0xFF...)` hardcodeado.

`onBrand` **no significa "blanco"** — significa "encima del relleno de marca", y se invierte con el tema. Lo que cae sobre una foto o un velo negro no depende del tema y se escribe `Colors.white` a pelo, con la razón documentada al lado.

Los ratios de contraste **se calculan, no se estiman** — hay un test que recalcula las dos paletas. Encontró `success` en 4.48:1 (0.02 por debajo de AA) tras un año sin que nadie lo notara, porque el token nació pensado para un punto de actividad (3:1) y luego pasó a pintar texto.

## Ningún texto visible se escribe en un widget (punto 11, ADR 0036)

Va en `app_es.arb` y `app_en.arb` y se lee con `context.l10n`. `L10n.current` solo se usa fuera del árbol (fallos de `data/` y `domain/`). Lo que viene del backend en español (catálogos, insignias) se traduce en el cliente **por `slug`**, nunca por el nombre. Lo que el servidor *comprueba* (la frase de borrado) solo se traduce si el servidor acepta también la traducción. [[0036-la-app-en-espanol-e-ingles|ADR 0036]].

## Un provider que depende de la sesión hace `ref.watch(authStateProvider)` (punto 12)

Leer el id una vez lo **congela** en el valor del primer lector, y si ese lector existe antes del login, en `null` para siempre. Un test que sobrescribe el provider con un valor fijo no lo ve.

## Un `label` en `Semantics` no silencia a sus hijos (punto 10)

Si el `child` dice algo que duplica o contradice el resumen, va `excludeSemantics: true`. Bajo el `InkWell` de una tarjeta pulsable la semántica se fusiona y el defecto es una palabra de más *dentro* de la frase, así que `find.bySemanticsLabel` no lo ve: se afirma sobre el `label` del nodo fusionado, lo que se oye **y lo que no**. Y `excludeSemantics` se lleva también la **acción** del hijo: si era pulsable, el `onTap` se repite en el `Semantics`, o TalkBack no puede pulsarlo (pasó con el micrófono de la sala).

## Ningún anuncio durante sala, llamada, chat o mensajería activa

El anuncio con recompensa solo lo lanza el usuario, y sus minutos los concede el **servidor** tras verificar la firma SSV de AdMob. [[0041-tope-diario-de-minutos-en-salas|ADR 0041]].

## Revisar `/pictures` antes de maquetar

Toda pantalla nueva revisa su boceto en `pictures/screens/` antes de implementar. Si falta, se pregunta antes de improvisar — nunca se inventa el diseño.

Ver también: [[Como-trabajar-en-este-repo]] (domain-modeling, tdd aplicados a UI), [[06-Agentes/Equipo-de-agentes|frontend-agent]].
