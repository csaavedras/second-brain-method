<!--
  TEMPLATE — copy to the root of EACH repo as CLAUDE.local.md and fill in.
  It's PERSONAL: not versioned. Use your GLOBAL gitignore to exclude it
  without touching the team's .gitignore:
    git config --global core.excludesFile ~/.gitignore_global
    (and add the line "CLAUDE.local.md" to that file)
  Claude Code loads it automatically alongside the team's CLAUDE.md if one
  exists: they coexist, this doesn't replace it.
  The method's rules do NOT go here: they live in ~/.claude/CLAUDE.md.
-->
<!-- method-version: 4.0 -->

# <project-name> — personal anchor

## Project
<!-- 2-3 lines: what it is + stack. Only what the agent needs to orient. -->
<...>

## Project brain
- Live state: `<vault>/projects/<project>/CONTEXT.md`
- Hub and history: `<vault>/projects/<project>/hub.md`

## Convention docs index
Read **on demand** only the ones relevant to the current task, not all:
<!-- The docs that EXIST in this repo, ONE line each: -->
- `<docs/...>.md` — <one line: what it covers>

## Safe commands for this repo
<!-- Document the "allow" of .claude/settings.local.json (personal; Claude
     Code excludes it from git automatically). Keep both in sync. -->
- build: `<command>`
- test: `<command>`
- lint: `<command>`

<!-- OPTIONAL — only LARGE repos with Graphify activated (method/GRAPHIFY.md).
     If this repo doesn't use the graph, delete this whole block: the section
     is the signal /start uses to refresh it and apply the 3-layer rule.

## Code graph (Graphify)
AST graph active in this repo (0 tokens, no API key). Refresh on session
open: `graphify update . --no-cluster`.

3-layer reading: structure → graph · state/decisions → vault · raw code →
only when editing. Queries (never load the graph into context):
- `graphify affected "<symbol>"` — who depends on X
- `graphify explain "<symbol>"` — one node + its neighbors
- `graphify query "<question>" --budget 800` — natural-language BFS
- `graphify path "<A>" "<B>"` — path between two symbols

Limit: symbol level (functions/classes/imports); module constants → grep.
-->

