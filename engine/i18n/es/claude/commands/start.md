---
description: Abrir sesión con el método — leer estado del vault y reportar
---

Abrí la sesión según el método de trabajo:

1. Ubicá la carpeta del proyecto en el vault usando el `CLAUDE.local.md` ya
   cargado en contexto (Claude Code lo carga en automático — no lo re-leas).
   Si este repo no tiene `CLAUDE.local.md`, frená y reportá: el método no
   está instanciado acá (ver CLAUDE-LOCAL.template.md del método).
2. Leé `<vault>/projects/<proyecto>/CONTEXT.md`.
3. Si CONTEXT.md referencia un plan en curso en `plans/`, leelo también.
4. **No re-explores el repo.** Usá el árbol cacheado en el `hub.md` del
   proyecto. Solo si el hub no tiene árbol, o CONTEXT.md indica que la
   estructura cambió, delegá el barrido al subagente Explore y actualizá el
   hub con el resultado.
5. Si el `CLAUDE.local.md` tiene la sección `## Grafo de código (Graphify)`:
   corré `graphify update . --no-cluster` (refresh AST, ~segundos, 0 tokens)
   y, durante la sesión, respondé las preguntas estructurales ("¿quién
   llama a…?", "¿de qué depende…?") con el grafo, no con barridos
   grep/Explore. Si no tiene la sección, salteá este paso sin comentar
   nada.

Reportá:
1. Estado actual según CONTEXT.md (3-5 líneas)
2. Próximo paso concreto del todo list (o del plan en curso)
3. Qué docs del índice de convenciones (CLAUDE.local.md) vas a leer para ese
   paso, y por qué

Esperá mi confirmación antes de escribir cualquier archivo.
