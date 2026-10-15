---
tags:
  - metodo
  - grasp
aliases:
  - Verificar desde cero
---

# Memoria persistente: punto de partida, nunca verdad asumida

> [!note] Regla central
> *"Implementación completa y pusheada"* no significa nada hasta reconstruir el entorno desde cero y
> ejecutar el flujo real. Esto aplica igual a lo que dice una memoria persistente de sesiones anteriores:
> es un punto de partida útil, nunca un hecho verificado sobre el estado actual.

## El precedente que fija esta regla

Comprobado el 2026-08-10 sobre el Bloque 3 de Grasp (avatares + foto de perfil): **17 commits en `master`**
daban la sensación de trabajo terminado y escondían tres bloqueantes que ningún test detectaba:

1. Una migración que abortaba `supabase start`.
2. Ocho PNG corruptos e **idénticos entre sí** (un asset binario roto no se detecta mirando la pantalla —
   hace falta decodificarlo con el decodificador real del producto, en este caso Flutter; un `errorBuilder`
   convierte un fichero roto en un icono gris plausible, que parece correcto a simple vista).
3. Un `service_role` sin un solo `GRANT`, que dejaba todas las Edge Functions en 500.

**Por qué pasó:** los entornos viejos tapan los fallos. Una base de datos que ya existía conserva grants y
objetos de antes del cambio, así que todo sigue funcionando mientras cualquier entorno **nuevo** — rama de
preview, restore, `supabase start` limpio — está roto. Y los ficheros de test colocados fuera de la carpeta
`test/` no los ejecuta nadie, así que un "N tests ✓" puede referirse a una suite que no cubre lo que se
acaba de escribir.

## Cómo se aplica

- Antes de aceptar que algo está terminado, **reconstruir desde cero** (`supabase db reset` en el caso de
  Grasp, el equivalente de "borra el entorno y vuelve a montarlo" en cualquier otro stack) y recorrer el
  flujo real de extremo a extremo, no solo la suite de tests.
- Contar **de dónde salen** los tests que se citan como prueba y confirmar que el fichero está en el sitio
  que el runner de verdad ejecuta.
- Para assets binarios, validarlos con el decodificador que usará el producto en producción, no mirando la
  pantalla de desarrollo.

## El mismo principio aplicado a los tests de regresión

Un test escrito para cubrir un bug recién arreglado **no está terminado hasta ejecutarlo contra el código
anterior y verlo fallar**. Si pasa en ambos, no es un guardia, es decoración.

Precedente (2026-08-12, `profile-photo-view-url`): el bug era que un UUID en mayúsculas no encontraba la
fila, porque Postgres serializa `uuid` en minúsculas. Se añadieron dos tests con el fixture que ya usaba el
fichero, `11111111-1111-4111-8111-111111111111` — que **no tiene ninguna letra `a`–`f`**, así que
`.toUpperCase()` devuelve la misma cadena. Los dos tests pasaban idénticos contra el código con el bug
puesto. El fixture heredado se elige por legibilidad, no por capacidad de distinguir — y eso lo vuelve
vacuo sin que nadie lo note.

Corolario sobre mutaciones: al comprobar que un test muerde, **una mutación puede no fallar, sino
reventar** (OOM, timeout, cuelgue) y no dejar ninguna línea `FAILED` que un `grep` pueda encontrar. Un bucle
infinito mata el proceso y un detector automático lo lee como "esta mutación no rompe nada" — justo lo
contrario de la verdad. Hay que mirar la salida **entera** y el código de salida, y acotar con `timeout`.

## Más formas de que una prueba nazca vacía (Fases 6–10a, octubre de 2026)

Todas son variantes de la misma idea: **un test solo vale si el caso malo es representable y alguien lo ha
visto fallar**.

| Trampa | Qué pasó | Cómo se evita |
|---|---|---|
| Fixture con la forma que supones | Los tests del cliente de LiveKit usaban camelCase; la API responde en snake_case. Suite en verde, reconciliación ciega en producción | El fixture de una API externa se **copia de una respuesta real** |
| Afirmar el código de error, no el mensaje | `42501` es igual para «la RLS te rechazó» y para «la policy no se puede evaluar»; lo segundo falla para todos | Afirmar el mensaje y poner al lado el caso positivo como control |
| Control que cruza el umbral mientras esperas | Un control a 9 min de un umbral de 10 se cerró antes de que el cron lo mirase: el mismo síntoma que el fallo | Control de casi-fallo con margen mayor que la latencia del tic; afirmar sobre los ids sembrados |
| Doble de test sin el ciclo de vida del real | Un `overrideWith` sin `ref.onDispose` no vio que la sala se desmontaba y cortaba la voz | El doble copia a mano lo que el proveedor real hace al liberarse |
| Lo que solo ve un dispositivo real | Reconectar es «caerse» para el webhook de LiveKit; TalkBack no podía pulsar el micrófono | Cada fase de voz se cierra con una **prueba de dos dispositivos reales** contra producción |

## Cómo se transporta a otro proyecto

1. Trata cualquier memoria, nota o resumen de sesión anterior como una **hipótesis sobre el pasado**, no
   como el estado actual. Antes de actuar sobre ella, verifica: ¿la función sigue existiendo?, ¿el token
   sigue vigente?, ¿el fichero sigue en esa ruta?
2. "Terminado" se demuestra reconstruyendo el entorno desde cero, nunca leyendo el historial de commits.
3. Un test de regresión se valida corriéndolo contra el código viejo y viéndolo fallar — si no falla ahí,
   no prueba nada.
4. Al mutar código para comprobar que un test lo detecta, mira la salida completa y el exit code, no solo
   si hay un `FAILED` — un cuelgue también es un fallo del test, aunque no lo diga.

[[Como-trabaja-Alfonso]] · [[Seguridad-higiene-de-secretos]]
