<!-- Method guide — lives in this folder, not copied into projects. -->
<!-- method-version: 4.0 -->

# MODEL-ROUTING.md — Choosing the model by task type

## The principle

The main session's model is set by the human (`/model`). But the agent
**chooses the model every time it delegates a task to a subagent** — that's
where the token savings live. The main session (parent agent) reasons with the
best available model; mechanical work is dispatched cheaply.

> **Golden rule:** every delegable task is delegated to the **cheapest model
> that solves it well**.

## The three levels

So this guide doesn't age with commercial names, the method defines levels;
the equivalences column is updated when the offering changes:

| Level | Role | Current model (Jul 2026) |
|---|---|---|
| **Explorer** | Search, read, summarize, verify state | Haiku 4.5 |
| **Implementer** | Execute well-defined tasks with a brief | Sonnet 5 |
| **Reasoner** | Plan, decide, review, debug | Opus 4.8 / Fable 5 (the session's main model) |

## Routing by task type

| Task | Level | Why |
|---|---|---|
| Code search/sweep ("where is X?", "what uses Y?") | Explorer | Short result; doesn't require deep reasoning |
| Summarize long docs or files | Explorer | Compression, not judgment |
| Verify state (run build/test and report the result) | Explorer | Execute and read output |
| Implement a task with a clear brief (endpoint, component, CRUD, tests) | Implementer | Closed scope and given conventions: the judgment is already decided |
| Bounded refactor with a known pattern | Implementer | The brief defines the pattern; you just apply it |
| Write technical documentation of what's already done | Implementer | Describes, doesn't decide |
| Plan / design architecture | Reasoner | An error here costs more than the tokens saved |
| Debugging of a non-obvious cause | Reasoner | Requires hypotheses and sustained reasoning |
| Code review of a diff | Reasoner | Catching the subtle stuff is exactly the point |
| Design decisions / trade-offs | Reasoner | And always with the human present in the decision |

## Escalation (never downgrade)

- If a subagent fails, reports doubts, or its output **doesn't pass the
  parent's verification** → the same task is re-dispatched **one level up**.
- Never the other way: don't downgrade the model mid-task.
- Two failures at the same level on the same task = a signal that the **brief
  is badly written**, not (only) that the model is too small. Review the brief
  before escalating again (see TASK-BRIEF.template.md).

## Where routing is exercised

- **On dispatch**: the model parameter when invoking the subagent.
- **In the subagent's definition**: the `model:` frontmatter of
  `~/.claude/agents/<name>.md` — each subagent type already ships with its
  default level (see MULTI-AGENT.md).

Two cases that sit outside the routing table (v4):

- **Fork** (subagent inheriting the parent's context, MULTI-AGENT.md): it
  always runs the **parent's model** — a model override is ignored. Never
  pick a fork to save tokens; pick it only when the task needs the session's
  history.
- **Fast mode** (`/fast`): same top model with faster output — it is NOT a
  cheaper level and doesn't replace routing. Like model/effort, toggle it at
  the `/close`→`/start` break, not mid-session (prefix-cache hygiene below).

## Prefix-cache hygiene (v3.2)

The API cache matches by **exact prefix** (not by semantics): it reuses the
computation as long as the start of the context doesn't change, billed at a
fraction of the cost of a new token. Implication for the **main session**:

- **Fix the model and effort level when OPENING the session.** Changing them
  mid-way —or altering the tool surface / the system prompt— **invalidates the
  whole cache** and forces recomputing the entire history. If you need a
  different model or effort, do it at the natural break: `/close` → new
  session.
- Keep the **prefix stable**: the always-active rules go at the top and stay
  put (thin CLAUDE.md); what mutates (the conversation) stays at the end.
- **Subagents do NOT suffer this**: each is its own ephemeral context, so
  per-dispatch model routing (Haiku/Sonnet/Opus) is free from the perspective
  of the parent's cache. This hygiene applies only to the main session.

## Context pruning — close, compact or branch (v3.2)

A session accumulates dead weight (long outputs, failed attempts) that dilutes
attention and burns tokens. Order of preference:

1. **Close and reopen** (default): you finished a task → `/close` → `/start`
   in a new session. The cleanest — the state lives in the vault, not in the
   thread.
2. **`/compact`** only mid-way through ONE long task you don't want to break:
   it condenses the history preserving the intent (rewrites the prefix → still
   breaks the cache).
3. **Branch** for risky experiments: a separate session to try a dubious
   refactor; if it goes wrong, discard it without dirtying the main one.
4. **`/clear`** after consolidating a module: resets the context counter
   keeping only the base prefix + the filesystem state.
