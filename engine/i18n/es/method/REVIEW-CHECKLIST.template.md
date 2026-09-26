<!--
  PLANTILLA — se instancia como <vault>/projects/<project>/review-checklist.md
  la primera vez que /learn review captura un comentario de MR del proyecto.
  La carga /gate en cada corrida: estas reglas tienen prioridad sobre el
  criterio genérico de review porque están destiladas de comentarios que ESTE
  proyecto realmente recibió.
  Regla de calidad: verificable de un vistazo a un diff. Si una regla necesita
  criterio ("el código debería ser prolijo"), no va acá — destilala más.
-->
<!-- method-version: 4.0 -->
---
type: checklist
project: <project>
date: <YYYY-MM-DD>
tags: [review]
---

# Checklist de review — <project>

Una regla por línea: **qué chequear** ← *origen (el comentario real de MR,
con fecha)*.

## Reglas

- <qué chequear, concretamente — p.ej. "todo endpoint nuevo valida params
  antes de usarlos"> ← <YYYY-MM-DD, MR #NN: "el comentario real del reviewer">

## Reglas retiradas
<!-- Reglas que dejaron de aplicar (cambio de stack, cambio de convención de
     equipo). Mantenerlas: documentan por qué se fueron. -->
