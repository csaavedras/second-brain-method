<!-- Guía del método — vive en esta carpeta, se lee bajo demanda. -->
<!-- method-version: 3.3 -->

# GRAPHIFY.md — Grafo de código AST (técnica opcional, solo suscripción)

Grafo de código para consultas estructurales ("¿quién llama a X?", "¿de qué
depende Y?") a **costo cero de tokens y sin API key**.

## Regla: cuándo usarlo
- **Repos GRANDES** (decenas+ de archivos, donde `grep` devuelve demasiados
  hits y orientarse obliga a leer muchos archivos) → el grafo paga.
- **Repos chicos** → **NO**: `grep` + el árbol cacheado de `hub.md` ya
  alcanzan y son más simples.
- **Opt-in por repo**, no por default. `/new-project` puede ofrecerlo, nunca
  lo impone.

## Modo sin API key (el único que usamos)
`graphify extract` (build semántico) requiere un `ANTHROPIC_API_KEY` pago —
**no se usa**. El camino gratis es puro AST (tree-sitter), 0 LLM:

```bash
pipx install graphifyy                 # once, isolated global
cd <repo>
graphify update . --no-cluster         # build/refresh AST → graphify-out/graph.json (0 tokens)
```

Consultas (traversal determinista sobre graph.json, 0 LLM, nunca cargan el
grafo entero al contexto):

```bash
graphify affected "<symbol>"           # reverse deps: who depends on X
graphify explain  "<symbol>"           # one node + its neighbors
graphify query "who calls the speak handler" --budget 800   # natural-language BFS, capped output
graphify path "A" "B"                  # shortest path between two symbols
```

## Activar en un repo (nuevo o existente)
Cuatro pasos, todos personales — no tocan nada versionado del equipo:

1. **Build inicial**: `cd <repo> && graphify update . --no-cluster`.
2. **Excluir el output**: agregar `graphify-out/` a `.git/info/exclude` del
   repo (exclusión personal por repo; el `.gitignore` del equipo no se toca).
3. **Allowlist**: agregar `"Bash(graphify:*)"` al `allow` de
   `.claude/settings.local.json` (las consultas son de solo lectura).
4. **Declararlo**: copiar la sección `## Code graph (Graphify)` de
   `CLAUDE-LOCAL.template.md` al `CLAUDE.local.md` del repo. Esa sección es
   la señal que usa `/start` para refrescar el grafo y aplicar la regla de
   3 capas. Sin la sección, el método ignora el grafo.

`/new-project` ofrece estos pasos al dar de alta un repo grande; en un repo
ya dado de alta se corren a mano una vez.

## CLI, no MCP
Existe un `graphify-mcp` (servidor MCP), pero **no se usa**: cada servidor
MCP carga los schemas de sus tools al contexto de *todas* las sesiones — un
costo fijo de tokens contrario al objetivo de esta técnica. El CLI vía Bash
con allowlist tiene un costo de contexto ~0 y hace lo mismo.

## Mantenerlo fresco (sin tokens)
`graphify update` corre en ~segundos a 0 tokens → barato de reconstruir:
`/start` lo refresca al abrir sesión en repos con el grafo declarado (paso 4
de la activación). Alternativas por repo si alguna vez hiciera falta más
frescura: `graphify watch <path>` o un hook de git — no son parte del método.

## Límites conocidos
- **Nivel símbolo**: captura funciones/clases/llamadas/imports/referencias,
  **no** el uso de constantes/variables de módulo (p.ej. `config.SPEAK` no
  resuelve) → para eso, usá `grep`.
- La fase semántica (conceptos de notas/PDFs) necesita un LLM/key → fuera de
  alcance de esta técnica.

## Regla de lectura en 3 capas (cuando el grafo está activo en un repo)
1. Estructura ("¿quién llama a…?", "¿de qué depende…?") → **grafo** (`query`/
   `affected`/`explain`).
2. Decisiones / estado / porqué → **vault** (CONTEXT, decisions, hub).
3. Código crudo → **solo al editar**.
