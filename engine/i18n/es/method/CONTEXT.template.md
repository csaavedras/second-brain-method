<!--
  PLANTILLA — copiar a <vault>/projects/<project>/CONTEXT.md y completar.
  ⚠️ EN LA INSTANCIA, el frontmatter (---) debe ser la PRIMERA línea del
  archivo: este bloque de comentario NO se copia, y el comentario de
  method-version va DESPUÉS del frontmatter (Obsidian y brain-health lo
  requieren).
  Es el ESTADO VIVO del proyecto y vive en el CEREBRO (vault), no en el repo.
  Se actualiza al cerrar CADA tarea.
  Regla: lo más reciente siempre arriba; lo viejo baja como "Historia
  previa".
  Archivado: fase completada o >~150 líneas → mover la historia cerrada a
  sessions/ (misma carpeta del proyecto) y dejar acá solo lo vivo.
  Ver el README.md y BRAIN.md del método.
-->

---
type: context
project: <project>
date: <YYYY-MM-DD>
status: active
---
<!-- method-version: 3.2 -->

# CONTEXT.md — <nombre-del-proyecto>

## Estado actual
Fecha de última actualización: <YYYY-MM-DD>
<!-- 3-6 líneas: qué se acaba de terminar, dónde está el proyecto, qué
     build/test corrió y con qué resultado (comando + resultado: es la
     evidencia de verificación). Al actualizar, bajar el bloque anterior
     con "Fecha anterior:". -->
<...>

## ⭐ PRÓXIMA SESIÓN — arrancar por acá
<!-- Lo primero que hay que hacer al retomar. Concreto y accionable.
     Si quedó una tarea a medias [~]: archivo que se estaba tocando, decisión
     pendiente, test que falla, comando que todavía hay que correr. -->
1. <...>
2. <...>

## Resumen de la tarea
<!-- Objetivo general, ticket/epic, subtareas si aplica.
     Si la tarea cruza repos: este proyecto del vault es el único dueño del
     estado; registrá acá qué se toca en cada repo (ver README §8). -->
<...>

## Decisiones de diseño tomadas
<!-- Cada decisión no-obvia, con su porqué. Las transversales también van
     como nota en decisions/ con un link acá y en el [[hub]].
     Al archivar, solo quedan acá las decisiones AÚN vigentes. -->
- <...>

## Todo list
<!-- Estado real del trabajo. [x] hecho (solo con build/test verde
     registrado), [ ] pendiente, [~] en curso o sin verificar.
     Para tareas grandes con un plan persistido: referenciá
     plans/<archivo>.md en vez de duplicar los pasos acá. -->
### <fase / hito>
- [ ] <...>
- [ ] <...>

## Notas de entorno / testing local
<!-- Cómo se levanta, variables, gotchas para testing local.
     ⚠️ El vault se sincroniza: NOMBRES de variables y dónde obtener sus
     valores (Secrets Manager, .env local, a quién pedirle acceso). NUNCA
     valores de secretos, tokens ni credenciales. -->
- <...>

## Hallazgos
<!-- Bugs, riesgos o deuda técnica detectados (aunque no se arreglen ahora).
     Los hallazgos sin confirmar se marcan como tales. -->
- <...>

## Preguntas abiertas
<!-- Lo que falta decidir/confirmar. Al resolverse, marcar [RESUELTO <fecha>]. -->
- <...>

<!-- Historia archivada (agregar cuando exista):
## Historia previa
- [[sessions/<YYYY-MM-DD>]]
-->
