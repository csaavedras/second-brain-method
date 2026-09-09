---
description: Close a task or a session — persist the state in the vault
---

Run the close per the method. Determine which case applies:

## A. Closing a completed task

1. **Verify before marking `[x]`**: run the appropriate build/test/lint and
   record in CONTEXT.md the command and its result. Without green, the task
   stays `[~]`. For non-trivial changes with a runtime surface, also
   exercise the flow end-to-end (native `/verify` skill) — green tests
   alone let through exactly the bugs that later show up as MR comments.
2. **Gate**: if the task produced code destined for a commit/MR, `/gate`
   must have run on the integrated diff with verdict **READY**. NOT-READY
   → the close stops here; the open findings decide the next step.
3. Update the vault's CONTEXT.md: task, new decisions, open questions,
   "Current state" with ISO date `YYYY-MM-DD`.
4. **Metrics**: run
   `~/second-brain/method/scripts/collect-metrics.sh` for this session, ask
   me two things — task `type` (feat / bug / refactor / spike) and optional
   `estimate` (points or time I had assigned) — and append the resulting
   line to `~/second-brain/projects/<project>/metrics/metrics.jsonl` (schema
   in `method/METRICS.md`). If the script fails, report it and continue:
   the close never blocks on telemetry.
5. Record cross-cutting things in the brain: non-obvious decision →
   `decisions/` (+ link in the hub); reusable learning → `patterns/` or
   `learning/`.
6. Leave the commit message ready: Conventional Commits with scope, English,
   one line, ≤ 100 characters.

Do not move to the next task until the 6 points are done.

## B. Closing a session with a task half-done

1. Mark the task `[~]` in the todo list.
2. Write into "⭐ NEXT SESSION" the **exact** point: file being touched,
   pending decision, failing test, command that still needs to run.
3. Record partial findings (marked as unconfirmed).
4. Update "Current state" with the date.

Acid test: a new session must resume without asking anything.

## Maintenance (check on every close)

- Phase completed or CONTEXT.md > ~150 lines → move the closed history to the
  project's `sessions/<YYYY-MM-DD>.md` and keep only what's live. Wikilink in
  "Previous history".
- The hub is updated only when closing **milestones**, not on every task.
- If the repo tree changed structurally in this session, update the hub's
  cached tree.

## Brain backup (last step, ALWAYS)

The vault (`~/second-brain`) is a git repo:

1. `git -C ~/second-brain status --porcelain` — if clean, done.
2. If there are changes: show me the summary and **with my OK** run add +
   commit: `chore(brain): YYYY-MM-DD close <project|study>` — a single commit
   with everything from the session.
3. If a remote is configured, push (also with my OK). If the push fails (no
   network, no remote), report it and finish anyway: the backup never blocks
   the close.

Note: this versions ONLY the vault. Each project's code repos have their own
git and their own rules (never without approval).
