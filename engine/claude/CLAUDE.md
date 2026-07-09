<!-- method-version: 3.2 — instance of CLAUDE-GLOBAL (thinned: the close
     detail lives in /close). Source: ~/second-brain/method/ -->

# Personal working method

## Brain
- Vault: `~/second-brain` — all method state lives there.
- Current project state: `<vault>/projects/<project>/`; the exact path is
  given by each repo's `CLAUDE.local.md`.

## Always-active rules
- Task that modifies code → **plan mode** and a plan as a todo list before
  touching files. Large tasks (several sessions or >~5 steps): save the
  approved plan in `<vault>/projects/<project>/plans/<YYYY-MM-DD>-<task>.md`.
- Never `git add` / `commit` / `push` / `checkout` without explicit approval.
- Never `rm` / `rmdir` / `mv` on files not created in the same session.
- Feature/fix on its own branch (`feat/<topic>`, `fix/<topic>`), never
  directly on `main`/`master`. Creating the branch also requires approval.
- Design decisions: always with the human present. No one decides downward.
- Secrets: never read or record values of tokens/credentials — only the
  names of variables and where to obtain their values.

## Context and delegation
- Convention docs: read on demand only the ones relevant to the task
  (index in the repo's `CLAUDE.local.md`), never all of them up front.
- The main session **orchestrates**: it holds the context and the decisions,
  and **delegates the changes**. Choose by goal (not by habit): search →
  **Explore**; implement → **`implementer`**; tests → **`tester`**; diff
  review → **`/code-review`**. The subagents are **generic-role** and detect
  the repo's stack — conventions live in its `CLAUDE.local.md`.
- Model by use (Explorer→Haiku · Implementer→Sonnet · Reasoner→Opus): every
  delegable task goes to the **cheapest model that solves it well** (detail
  in `method/MODEL-ROUTING.md` and `MULTI-AGENT.md`).
- Verify the subagent's report before considering the task done. In the
  `/start` report, name which skill/role and which model will be used.

## Sessions
- Open a session: `/start`. Close each task or the session: `/close` —
  mandatory before moving to the next task or stopping.
- Model and effort are fixed when opening; changing them mid-way **invalidates
  the cache** → do it at the `/close`→`/start` break. Context pruning and
  detail in `method/MODEL-ROUTING.md`.
