# Revisión crítica del producto y de su lógica

> Principio del vault (Sección 0.1): avisar antes de implementar algo arriesgado, con una alternativa concreta, y documentar el desacuerdo si se mantiene.
> Varias decisiones de abajo están en la lista "no reabrir" de CLAUDE.md §13. **No las he cambiado en el código**: las señalo porque el coste de equivocarse es alto. Cada punto termina con mi recomendación.

## Prioridad 1 · Bloqueantes de publicación o de seguridad

### R1. Menores de 14–17 en llamadas de voz 1:1 con desconocidos, sin moderación
- La combinación **edad mínima 14 + audio privado con un extraño + chat privado + grabación + "sin moderación"** es el escenario clásico de riesgo de *grooming*. El propio vault subió Grasp a 18 por este motivo (ADR 0044).
- **Tiendas:** Apple (guía 1.2, contenido generado por usuarios) exige poder **reportar** y **bloquear** usuarios y un contacto para incidencias; Google Play (política de UGC) exige reporte y bloqueo dentro de la app. Sin eso, el rechazo en revisión es probable.
- **UE:** con menores, la DSA (art. 28) prohíbe la publicidad personalizada basada en perfiles → AdMob tiene que marcarse como `tagForUnderAgeOfConsent`/no personalizado para menores de 18.
- **Recomendación:** (a) edad mínima 18, **o** colas y agenda separadas 14–17 / 18+; (b) en ambos casos, bloquear (no volver a emparejar + chat cerrado) y reportar con revisión humana (patrón del ADR 0043 del vault: la máquina detecta, una persona sanciona). Coste estimado: 1 tabla + 2 funciones + 2 botones.

### R2. "Exámenes ilimitados" con 5 exámenes por nivel
- El paywall promete ilimitados; la rotación evita repetir. Un estudiante que haga 3 sesiones a la semana agota su nivel en menos de 2 semanas y empieza a repetir: es justo el usuario que paga.
- **El contenido es el producto.** Recomendación: objetivo de 30+ exámenes por nivel antes de cobrar, con pipeline de generación + **revisión humana** de dificultad (descriptores MCER) y sin usar la marca "Cambridge" como reclamo (es marca registrada; usar "formato tipo Cambridge" + aviso de no afiliación).

## Prioridad 2 · Riesgos de negocio y de experiencia

### R3. Teléfono sin verificar que nadie lee
- Ningún flujo lo usa. Es dato personal sin finalidad (RGPD 5.1.c); el vault lo **borró** en Grasp por exactamente esto (ADR 0015). Recomendación: no pedirlo. Hoy está implementado como **opcional**.

### R4. El test de prueba se gasta aunque el compañero te deje tirado
- Si el otro abandona o se desconecta en el minuto 1 de la Parte 1, el usuario nuevo pierde su única prueba por culpa ajena: primera impresión pésima justo antes del paywall.
- Recomendación: devolver el test si la sesión aborta por el **otro** antes de la Parte 3. Con el esquema actual son ~10 líneas en `svc_session_tick`/`svc_session_abort`.

### R5. Liquidez (arranque en frío) del emparejamiento en vivo
- Cola por nivel exacto + solo usuarios que pagan → con pocos usuarios, esperas largas y abandono. El paywall reduce además la oferta de compañeros.
- Recomendación: lanzar con la **agenda como camino principal**, "horas punta" anunciadas, contador de gente buscando, y permitir nivel adyacente en vivo *opt-in* tras 60 s.

### R6. App Open Ad para quien paga 8 €/mes
- Ingreso por impresión mínimo frente al daño de percepción ("pago y me ponen anuncios"). Recomendación: solo a quien no tiene suscripción.

### R7. Coste variable sin tope
- LiveKit cobra por participante-minuto y Egress por grabación. "Ilimitado" sin tope diario permite abuso (dos cuentas en bucle). Lección del vault: calcular el coste del **abuso**, no del usuario medio. Recomendación: tope de sesiones/día por usuario (p. ej. 6) en `svc_match_enqueue`/`svc_meeting_enter`.

### R8. Bloque de 30 min por reunión
- Lobby (5) + examen (12–15) + feedback (5) ≈ 25 min; con los 10 min de cortesía una reunión puede acabar a +35 y pisar la siguiente confirmada. Recomendación: bloque de 45 min o cerrar la entrada a +5 min.

### R9. Zonas horarias
- Dos estudiantes en zonas distintas verán horas distintas. Todo se guarda en `timestamptz`; la UI debe mostrar la hora local y avisar cuando la del otro difiere.

## Prioridad 3 · Riesgos técnicos anticipados

### R10. Audio en iOS: lector + llamada + segundo plano
- Reproducir el TTS con un reproductor propio mientras WebRTC tiene la sesión de audio es la parte más frágil del proyecto (categoría `playAndRecord`, ducking, auriculares Bluetooth, eco por altavoz). En segundo plano, iOS suspende el reproductor si no hay modo de audio de fondo.
- Plan: pedir auriculares antes del lobby; probar pronto en dispositivo real. **Plan B** si falla: que el servidor publique el audio del lector como pista de LiveKit (un "agente" en la sala): sincronía perfecta y una sola sesión de audio, a cambio de coste de servidor.

### R11. Sincronía entre dispositivos
- El estado sale de `now − exam_started_at`, así que un reloj del móvil desviado 3 s desincroniza al lector. La respuesta de `session-actions` incluye `server_now`: la app debe estimar el desfase (tipo NTP, mitad del RTT) y usar ese reloj. Ya está previsto en `ExamEngine` (recibe `nowMs`).

### R12. Contenido empaquetado vs. servidor
- Un examen nuevo exige publicar app. Resuelto a medias con `content_version` (D-012). A medio plazo conviene servir el JSON también desde R2 con firma de versión.

### R13. Spam y abuso en endpoints
- Sin límite: subidas de avatar (el vault ya lo apuntaba como hueco), mensajes de chat, creación/cancelación de ofertas. Añadir límites por usuario antes de abrir.

## Sobre las pantallas

- Login dice "Al continuar aceptas los Términos" **y** el paso 3 tiene casilla de aceptación: sobra uno. Recomendación: quitar la frase del login (la aceptación con versión y fecha se guarda en el paso 3, que es lo que exige CLAUDE.md).
- El onboarding de los bocetos agrupa los 8 pasos en 3 pantallas: correcto, se respeta el orden.
- Paywall: añadir enlace a gestión de suscripción, precio con impuestos y periodo, y "Restaurar compras" (ya está): requisitos de Apple.
- Parte 2 (C1): "dani_r elige dos de estas fotos" mientras habla; el que escucha también ve las fotos: correcto y coincide con el examen real.
- "Mientras esperas" con consejos en la búsqueda: buena idea, barata, y convierte la espera en valor.
