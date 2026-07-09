<!--
  TEMPLATE — copy to <vault>/projects/<project>/CONTEXT.md and fill in.
  ⚠️ IN THE INSTANCE, the frontmatter (---) must be the FIRST line of the
  file: this comment block is NOT copied, and the method-version comment goes
  AFTER the frontmatter (Obsidian and brain-health require it).
  It's the project's LIVE STATE and lives in the BRAIN (vault), not the repo.
  It's updated on closing EVERY task.
  Rule: the most recent thing is always at the top; the old moves down as
  "Previous date".
  Archiving: phase completed or >~150 lines → move the closed history to
  sessions/ (same project folder) and keep only what's live here.
  See the method's README.md and BRAIN.md.
-->

---
type: context
project: <project>
date: <YYYY-MM-DD>
status: active
---
<!-- method-version: 3.2 -->

# CONTEXT.md — <project-name>

## Current state
Last update date: <YYYY-MM-DD>
<!-- 3-6 lines: what was just finished, where the project stands, which
     build/test ran and with what result (command + result: it's the
     verification evidence). When updating, move the previous block below
     with "Previous date:". -->
<...>

## ⭐ NEXT SESSION — start here
<!-- The first thing to do when resuming. Concrete and actionable.
     If a task was left half-done [~]: file being touched, pending decision,
     failing test, command that still needs to run. -->
1. <...>
2. <...>

## Task summary
<!-- General goal, ticket/epic, subtasks if applicable.
     If the task crosses repos: this vault project is the sole owner of the
     state; record here what's touched in each repo (see README §8). -->
<...>

## Design decisions made
<!-- Each non-obvious decision, with its why. The cross-cutting ones also go
     as a note in decisions/ with a link here and in the [[hub]].
     When archiving, only STILL-CURRENT decisions remain here. -->
- <...>

## Todo list
<!-- Real state of the work. [x] done (only with build/test green recorded),
     [ ] pending, [~] in progress or unverified.
     For large tasks with a persisted plan: reference plans/<file>.md instead
     of duplicating the steps here. -->
### <phase / milestone>
- [ ] <...>
- [ ] <...>

## Environment / local testing notes
<!-- How it's brought up, variables, gotchas for local testing.
     ⚠️ The vault is synced: NAMES of variables and where to obtain their
     values (Secrets Manager, local .env, whom to ask for access). NEVER
     values of secrets, tokens or credentials. -->
- <...>

## Findings
<!-- Bugs, risks or tech debt detected (even if not fixed now).
     Unconfirmed findings are marked as such. -->
- <...>

## Open questions
<!-- What's left to decide/confirm. When resolved, mark [RESOLVED <date>]. -->
- <...>

<!-- Archived history (add when it exists):
## Previous history
- [[sessions/<YYYY-MM-DD>]]
-->
