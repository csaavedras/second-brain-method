<!--
  PLANTILLA — copiar a la raíz de CADA repo como CLAUDE.local.md y completar.
  Es PERSONAL: no se versiona. Usá tu gitignore GLOBAL para excluirlo sin
  tocar el .gitignore del equipo:
    git config --global core.excludesFile ~/.gitignore_global
    (y agregar la línea "CLAUDE.local.md" a ese archivo)
  Claude Code lo carga en automático junto con el CLAUDE.md del equipo si
  existe: conviven, este no lo reemplaza.
  Las reglas del método NO van acá: viven en ~/.claude/CLAUDE.md.
-->
<!-- method-version: 3.3 -->

# <nombre-del-proyecto> — anclaje personal

## Proyecto
<!-- 2-3 líneas: qué es + stack. Solo lo que el agente necesita para ubicarse. -->
<...>

## Cerebro del proyecto
- Estado vivo: `<vault>/projects/<proyecto>/CONTEXT.md`
- Hub e historia: `<vault>/projects/<proyecto>/hub.md`

## Índice de docs de convenciones
Leer **bajo demanda** solo los relevantes a la tarea en curso, no todos:
<!-- Los docs que EXISTAN en este repo, UNA línea cada uno: -->
- `<docs/...>.md` — <una línea: qué cubre>

## Comandos seguros de este repo
<!-- Documentan el "allow" de .claude/settings.local.json (personal; Claude
     Code lo excluye de git en automático). Mantener ambos en sincronía. -->
- build: `<comando>`
- test: `<comando>`
- lint: `<comando>`

<!-- OPCIONAL — solo repos GRANDES con Graphify activado (method/GRAPHIFY.md).
     Si este repo no usa el grafo, borrá este bloque entero: la sección es la
     señal que /start usa para refrescarlo y aplicar la regla de 3 capas.

## Grafo de código (Graphify)
Grafo AST activo en este repo (0 tokens, sin API key). Refrescar al abrir
sesión: `graphify update . --no-cluster`.

Lectura en 3 capas: estructura → grafo · estado/decisiones → vault ·
código crudo → solo al editar. Consultas (nunca cargan el grafo al contexto):
- `graphify affected "<símbolo>"` — quién depende de X
- `graphify explain "<símbolo>"` — un nodo + sus vecinos
- `graphify query "<pregunta>" --budget 800` — BFS en lenguaje natural
- `graphify path "<A>" "<B>"` — camino entre dos símbolos

Límite: nivel símbolo (funciones/clases/imports); constantes de módulo → grep.
-->
