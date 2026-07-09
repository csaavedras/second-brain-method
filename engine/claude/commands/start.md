---
description: Open a session with the method — read vault state and report
---

Open the session per the working method:

1. Locate the project's folder in the vault using the `CLAUDE.local.md`
   already loaded in context (Claude Code loads it automatically — don't
   re-read it). If this repo has no `CLAUDE.local.md`, stop and report: the
   method is not instantiated here (see the method's CLAUDE-LOCAL.template.md).
2. Read `<vault>/projects/<project>/CONTEXT.md`.
3. If CONTEXT.md references an in-progress plan in `plans/`, read it too.
4. **Do not re-explore the repo.** Use the cached tree in the project's
   `hub.md`. Only if the hub has no tree, or CONTEXT.md indicates the
   structure changed, delegate the sweep to the Explore subagent and update
   the hub with the result.

Report:
1. Current state per CONTEXT.md (3-5 lines)
2. Concrete next step from the todo list (or the in-progress plan)
3. Which convention-index docs (CLAUDE.local.md) you'll read for that step,
   and why

Wait for my confirmation before writing any file.
