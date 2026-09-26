---
description: Dar de alta un proyecto en el método — scaffolding vault + repo en un paso
argument-hint: [nombre-del-proyecto]
---

Dá de alta este proyecto en el método de trabajo. Nombre: $ARGUMENTS
(si está vacío, proponé uno a partir del directorio actual y esperá mi OK).

Plantillas y guías del método: `@@VAULT@@/method/`.
Vault: `@@VAULT@@`.

## Pre-chequeos (si alguno falla, frenar y reportar)

1. Estás en la raíz de un repo git. Si todavía no hay repo, proponé
   `git init` — es un comando git: requiere mi aprobación explícita.
2. No existe ya `CLAUDE.local.md` acá ni `<vault>/projects/<nombre>/`.
   Si existen, el proyecto ya está dado de alta: reportá el estado y frená.
3. `git check-ignore -q CLAUDE.local.md` confirma que el gitignore global
   lo excluye (si no, reportá antes de seguir).

## Scaffolding en el vault — `projects/<nombre>/`

1. Crear `plans/`, `sessions/`, `decisions/`.
2. `hub.md` según la plantilla de BRAIN.md: qué es (preguntame si no surge
   del repo), ruta absoluta del repo, stack en una línea, estado macro
   inicial. Agregá una sección `## Repo tree` con el árbol de carpetas
   (el cache que usa /start — sin node_modules ni outputs de build).
3. `CONTEXT.md` desde `CONTEXT.template.md`:
   - **Proyecto nuevo**: estado "recién dado de alta", todo list vacío,
     "⭐ PRÓXIMA SESIÓN" apuntando a definir el primer objetivo.
   - **Repo existente**: la foto real de partida — qué está hecho, qué
     falta, decisiones ya visibles en el código. El barrido lo hace el
     subagente Explore, no esta sesión.

## Scaffolding en el repo (nada versionado)

4. `CLAUDE.local.md` desde `CLAUDE-LOCAL.template.md`: descripción de 2-3
   líneas, rutas del cerebro del proyecto, índice de docs de convenciones
   que **existan** (documentar, no inventar; si no hay: "(ninguno
   todavía)"), y comandos reales de build/test/lint (leelos de
   package.json/Makefile — no los inventes).
5. `.claude/settings.local.json`:
   - `allow`: los comandos de build/test/lint reales del repo + lecturas
     (`grep`, `find`, `ls`, `cat`) + `Read` del vault.
   - `deny`: `Read` de `.env*`, `*.pem`, `*.key`, `secrets/`,
     `credentials/`, `.aws/`, `.ssh/`.
   - `ask`: `git add/commit/push/checkout`, `rm`, `mv`.

## Grafo de código (opt-in, solo repos grandes)

6. Si el repo tiene **decenas o más de archivos fuente** (donde grep ya no
   orienta), **ofrecé** activar Graphify — nunca lo impongas ni lo actives
   sin OK. Si acepto: seguí los 4 pasos de "Activar en un repo" de
   `@@VAULT@@/method/GRAPHIFY.md` (build AST sin key,
   `.git/info/exclude`, allowlist, sección en CLAUDE.local.md). Repos
   chicos: ni ofrecerlo.

## Cierre

7. Agregar el proyecto a "Proyectos activos" de `00-index/home.md` con
   wikilink al hub.
8. Reportá: archivos creados, marcadores `<...>` que quedaron por completar
   a mano, y el recordatorio de que la primera sesión de trabajo se abre
   con `/start`.

Reglas fijas: no toques nada versionado del repo (el método no se impone al
equipo) y no corras ningún comando git sin aprobación.
</content>
