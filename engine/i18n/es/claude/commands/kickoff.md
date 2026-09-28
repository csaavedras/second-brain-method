---
description: Arrancar un proyecto desde el prompt maestro — alta + cerebro + primer plan
argument-hint: [nombre] [ruta al brief, o pegalo en el mensaje]
---

Arrancá este proyecto a partir del PROMPT MAESTRO. Argumentos: $ARGUMENTS

**Fuente del brief**, en este orden: (a) ruta de archivo en los argumentos,
(b) texto pegado en este mensaje, (c) si no hay ninguno → completalo
conmigo **pregunta por pregunta** siguiendo la estructura de
`@@VAULT@@/method/PROJECT-BRIEF.template.md` (una sección a la vez,
con ejemplos; las que no sepa quedan "A DECIDIR").

## Paso 1 — Alta del proyecto (si hace falta)

Si este repo no tiene `CLAUDE.local.md`: leé y ejecutá primero los pasos de
`~/.claude/commands/new-project.md` (pre-chequeos incluidos). Si ya está
dado de alta, seguí directo.

## Paso 2 — Persistir el prompt maestro

Guardalo como `<vault>/projects/<nombre>/brief.md` con el frontmatter de la
plantilla (`type: brief`, `project`, `date`, `status: current`). Es la
fuente de verdad de la visión: no se reescribe — si la visión cambia, se
enmienda con fecha.

## Paso 3 — Derivar el cerebro desde el brief

- `hub.md`: "Qué es" ← Visión (§1); "Stack" ← lo **fijo** de §6.
- `CONTEXT.md`: "Resumen de la tarea" ← Alcance MVP (§4) + Fuera de alcance
  (§5); "Preguntas abiertas" ← Riesgos y dudas (§9); "⭐ PRÓXIMA SESIÓN" ←
  "aprobar el plan del MVP".
- `decisions/`: **una nota por cada decisión ya fijada** en §6 (ej. el
  stack), con el porqué que dé el brief. Lo "A DECIDIR" **no** genera nota:
  queda como pregunta abierta.

## Paso 4 — Primer plan (plan mode)

1. Si hay dudas de §9 que **bloquean** el plan, preguntámelas antes.
2. Entrá en **plan mode** y proponé el plan del MVP: fases cortas y
   verificables, derivadas del Alcance (§4) y los Criterios de éxito (§8).
   La primera fase termina siempre en algo que corre (walking skeleton).
3. Al aprobarse: guardalo en `plans/<AAAA-MM-DD>-mvp.md` y referencialo
   desde el todo list de CONTEXT.md (no dupliques los pasos).

## Reglas fijas

- Lo "A DECIDIR" del brief son decisiones de diseño → se resuelven conmigo,
  nunca las inventes.
- Nada de git sin mi aprobación (incluido `git init` si el repo es nuevo).
- Al terminar, reportá: brief guardado, notas creadas, plan aprobado, y el
  recordatorio de cerrar con /close.
