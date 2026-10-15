---
tags:
  - metodo
  - grasp
  - index
aliases:
  - Método — índice
---

# 00-Método — índice

Esta carpeta es la parte transferible a **cualquier proyecto nuevo**: no qué es Grasp, sino cómo colaborar
con Alfonso y qué patrones de proceso reutilizar.

- [[Arrancar-un-proyecto-nuevo]] — **empieza aquí si vas a montar un proyecto nuevo**: qué piezas de Grasp
  se copian, cuáles no y en qué orden se arranca.
- [[Como-trabaja-Alfonso]] — perfil del usuario: solo, aprendiendo infra sobre la marcha, decide rápido con
  una recomendación razonada, todo en español, y la lista de "qué NO hacer".
- [[Principio-cuestionar-antes-de-implementar]] — Sección 0.1: avisar antes de implementar algo inseguro o
  mal planteado; si el usuario insiste, se respeta y se documenta el desacuerdo.
- [[Retroalimentacion-continua]] — Sección 0.2: ningún `.md` es estático; corregir sin documentar deja la
  misma trampa para la siguiente sesión.
- [[Documentar-decisiones-como-narrativa]] — los ADR son prosa, no actas; "documentar a fondo" es barrer
  toda la documentación afectada en el mismo turno.
- [[Sistema-de-skills-y-precedentes]] — la regla (barata, siempre cargada) vive separada del precedente
  (caro, cargado solo por dominio); la pieza más reutilizable de todo el método.
- [[Memoria-persistente-y-verificacion]] — una memoria o un commit "terminado" es una hipótesis, no un
  hecho, hasta reconstruir el entorno y verlo funcionar.
- [[Seguridad-higiene-de-secretos]] — nunca leer/pedir valores de secretos; patrón del hash en vez de
  copiar a mano; comandos de infraestructura que filtran credenciales por defecto.
