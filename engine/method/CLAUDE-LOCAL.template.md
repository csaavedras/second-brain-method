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
<!-- method-version: 3.2 -->

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
