<!-- Method guide — lives in this folder, read on demand. -->
<!-- method-version: 4.0 -->

# GRAPHIFY.md — AST code graph (optional, no model API required)

Code graph for structural queries ("who calls X?", "what does Y depend on?")
at **zero token cost and no API key**.

## Rule: when to use it
- **LARGE repos** (dozens+ of files, where `grep` returns too many hits and
  orienting yourself means reading many files) → the graph pays off.
- **Small repos** → **NO**: `grep` + the cached tree in `hub.md` already
  suffice and are simpler.
- **Opt-in per repo**, not by default. The new-project workflow may offer it, never
  impose it.

## No-API-key mode (the only one we use)
`graphify extract` (semantic build) requires a paid `ANTHROPIC_API_KEY` —
**not used**. The free path is pure AST (tree-sitter), 0 LLM:

```bash
pipx install graphifyy                 # once, isolated global
cd <repo>
graphify update . --no-cluster         # build/refresh AST → graphify-out/graph.json (0 tokens)
```

Queries (deterministic traversal over graph.json, 0 LLM, never load the
whole graph into context):

```bash
graphify affected "<symbol>"           # reverse deps: who depends on X
graphify explain  "<symbol>"           # one node + its neighbors
graphify query "who calls the speak handler" --budget 800   # natural-language BFS, capped output
graphify path "A" "B"                  # shortest path between two symbols
```

## Activating in a repo (new or existing)
Four steps, all personal — nothing versioned by the team is touched:

1. **Initial build**: `cd <repo> && graphify update . --no-cluster`.
2. **Exclude the output**: add `graphify-out/` to the repo's
   `.git/info/exclude` (personal per-repo exclusion; the team's `.gitignore`
   is not touched).
3. **Permissions**: retain normal runtime sandbox/approval gates for updates.
   Queries are read-only. Do not broadly allow every Graphify subcommand.
4. **Declare it**: add `## Code graph (Graphify)` to the project's shared
   `hub.md` with the refresh command. Both runtimes read this opt-in. Claude
   also honors an existing legacy anchor declaration; migrate it to the hub
   for cross-provider use.

The new-project workflow offers these steps when registering a large repo; in an
already-registered repo run them by hand once.

## CLI, not MCP
A `graphify-mcp` (MCP server) exists, but it is **not used**: every MCP
server loads its tool schemas into the context of *all* sessions — a fixed
token cost contrary to this technique's goal. The CLI via Bash with an
allowlist has ~0 context cost and does the same.

## Keeping it fresh (no tokens)
`graphify update` rebuilds the AST without model calls. The start workflow
refreshes it when opening a session in repos with the graph declared (step 4
of the activation). Per-repo alternatives if more freshness is ever needed:
`graphify watch <path>` or a git hook — not part of the method.

## Known limits
- **Symbol level**: captures functions/classes/calls/imports/references,
  **not** module constant/variable usage (e.g. `config.SPEAK` doesn't
  resolve) → use `grep` for that.
- The semantic phase (concepts from notes/PDFs) needs an LLM/key → out of
  scope for this technique.

## 3-layer reading rule (when the graph is active in a repo)
1. Structure ("who calls…?", "what depends on…?") → **graph** (`query`/
   `affected`/`explain`).
2. Decisions / state / why → **vault** (CONTEXT, decisions, hub).
3. Raw code → **when inspecting actual implementation or editing**.

Claude Code and Codex share this CLI-first strategy and the same graph. If the CLI
is missing, fall back to bounded searches; graph availability never blocks work.
