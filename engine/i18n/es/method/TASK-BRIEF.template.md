<!--
  PLANTILLA — el agente padre la completa para CADA despacho de subagente.
  El brief es efímero: vive en el prompt del despacho, no se copia al repo.
  Los briefs que valga la pena reutilizar se guardan en el cerebro (briefs/).
  Regla de calidad: el subagente NO debería necesitar nada fuera de este
  brief.
  Ver MULTI-AGENT.md y MODEL-ROUTING.md.
-->
<!-- method-version: 4.0 -->

# TASK BRIEF — <título corto de la tarea>

## Objetivo
<!-- 1-3 líneas: qué debe existir/funcionar cuando termines. -->
<...>

## Contexto mínimo
<!-- Solo lo necesario: qué es el proyecto en 2 líneas + la decisión de
     diseño relevante a ESTA tarea, si la hay. NO pegar el CONTEXT.md
     completo. -->
<...>

## Archivos relevantes
<!-- Rutas concretas con el porqué. El subagente no explora a ciegas. -->
- `<path>` — <por qué es relevante>

## Convenciones a seguir
<!-- Pointers puntuales, no "leé todos los docs": -->
- Leé `<docs/0X-...>.md` y seguí ese patrón para <...>

## Skills a usar
<!-- 0-2 skills elegidos del registro (SKILLS-REGISTRY.md), cada uno con una
     línea de por qué. Omitir si ninguno aplica — la mayoría de las tareas no
     necesita ninguno. -->
- <skill> — <por qué aplica a ESTA tarea>

## Criterios de aceptación
<!-- Dos bloques. El subagente NO termina hasta que cada ítem tenga
     evidencia. -->
Comandos (deben pasar en verde):
- `<comando de test/build/lint>` en verde

Comportamiento observable:
<!-- Afirmaciones concretas y verificables — "devuelve 404 cuando X",
     "loguea el error con contexto", "el flag viene apagado por default". No
     vibes. -->
- <...>

## Restricciones (fijas del método — no editar)
- Trabajá SOLO dentro del alcance de este brief; si falta algo, reportalo
  como bloqueo, no lo resuelvas por tu cuenta.
- No ejecutes comandos git. No modifiques CONTEXT.md ni archivos de estado.
- No tomes decisiones de diseño: las dudas vuelven en el reporte.
- Invocá solo los skills nombrados arriba; no elijas skills por tu cuenta.

## Formato del reporte (obligatorio, máx ~30 líneas)
1. Stack/framework detectado + convenciones seguidas (1-2 líneas)
2. Archivos tocados y qué cambió en cada uno (1 línea por archivo)
3. Verificación — una línea por comando, EXACTAMENTE con esta forma (el
   harness la valida): ``Verification: `<comando>` → <resultado literal>``
4. Criteria evidence (evidencia por criterio): cada criterio de aceptación →
   su evidencia (1 línea cada uno)
5. Hallazgos (si hubo)
6. Dudas / bloqueos (si hubo)
