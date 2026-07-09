---
description: Register a project in the method — vault + repo scaffolding in one step
argument-hint: [project-name]
---

Register this project in the working method. Name: $ARGUMENTS
(if empty, propose one from the current directory and wait for my OK).

Method templates and guides: `~/second-brain/method/`.
Vault: `~/second-brain`.

## Pre-checks (if any fails, stop and report)

1. You're at the root of a git repo. If there's no repo yet, propose
   `git init` — it's a git command: requires my explicit approval.
2. Neither `CLAUDE.local.md` here nor `<vault>/projects/<name>/` already
   exists. If they do, the project is already registered: report the state
   and stop.
3. `git check-ignore -q CLAUDE.local.md` confirms the global gitignore
   excludes it (if not, report before continuing).

## Scaffolding in the vault — `projects/<name>/`

1. Create `plans/`, `sessions/`, `decisions/`.
2. `hub.md` per the BRAIN.md template: what it is (ask me if it's not clear
   from the repo), absolute repo path, stack in one line, initial macro
   state. Add a `## Repo tree` section with the folder tree (the cache /start
   uses — without node_modules or build outputs).
3. `CONTEXT.md` from `CONTEXT.template.md`:
   - **New project**: state "just registered", empty todo list, "⭐ NEXT
     SESSION" pointing to defining the first goal.
   - **Existing repo**: the real starting snapshot — what's done, what's
     missing, decisions already visible in the code. The sweep is done by
     the Explore subagent, not this session.

## Scaffolding in the repo (nothing versioned)

4. `CLAUDE.local.md` from `CLAUDE-LOCAL.template.md`: 2-3 line description,
   project brain paths, index of convention docs that **exist** (document,
   don't invent; if none: "(none yet)"), and real build/test/lint commands
   (read them from package.json/Makefile — don't invent them).
5. `.claude/settings.local.json`:
   - `allow`: the repo's real build/test/lint commands + reads (`grep`,
     `find`, `ls`, `cat`) + `Read` of the vault.
   - `deny`: `Read` of `.env*`, `*.pem`, `*.key`, `secrets/`,
     `credentials/`, `.aws/`, `.ssh/`.
   - `ask`: `git add/commit/push/checkout`, `rm`, `mv`.

## Wrap-up

6. Add the project to "Active projects" in `00-index/home.md` with a wikilink
   to the hub.
7. Report: files created, `<...>` placeholders left to fill in by hand, and
   the reminder that the first work session is opened with `/start`.

Fixed rules: don't touch anything versioned in the repo (the method is not
imposed on the team) and don't run any git command without approval.
