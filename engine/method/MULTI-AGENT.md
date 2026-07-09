<!-- Method guide — lives in this folder, not copied into projects. -->
<!-- method-version: 3.2 -->

# MULTI-AGENT.md — Parent → Subagents flow

## Architecture

```
PARENT AGENT (main session)
  · The only one with historical context: CONTEXT.md, plan, decisions, brain
  · Orchestrates: plans, writes briefs, dispatches, verifies, integrates
  · The only one that updates CONTEXT.md and proposes git commands
  · Does not implement large tasks directly
        │  dispatches with a TASK BRIEF + model per MODEL-ROUTING.md
        ▼
SUBAGENT (ephemeral, one per task)
  · Context = ONLY its brief: goal, files, pointed conventions
  · Generic role and stack-agnostic: detects the repo's stack; reads
    conventions from the repo's CLAUDE.local.md
  · Does NOT read CONTEXT.md, does NOT touch git, does NOT decide design
  · Returns a REPORT with a fixed format and bounded length
```

The separation protects two things at once: **tokens** (the subagent doesn't
load history it doesn't need; the parent isn't polluted with the subagent's
intermediate output) and **security** (the state and git have a single owner).

## The Parent Agent

- It's the main Claude Code session, with the Reasoner model.
- On opening a session it loads the state (CONTEXT.md + in-progress plan) —
  it's the only one that does so.
- For each task in the approved plan it decides: inline or delegate? (context
  hygiene heuristic, README §5.4).
- If it delegates: it writes the **task brief** (TASK-BRIEF.template.md),
  picks the subagent from the catalog and the model per MODEL-ROUTING.md.
- On receiving the report: it **verifies the evidence** before marking `[x]`
  — it never trusts the subagent's "done" without verifying. If the report
  brings the literal green output, re-running the cheapest command (lint or
  the specific test) is enough; full re-verification is reserved for
  integrations or dubious reports.
- Integrates: updates CONTEXT.md, leaves the commit message, moves on to the
  next task.

## The Subagents

Fixed rules (they go in the prompt of every subagent definition):

1. Work **only** within the brief's scope. If information is missing, report
   it as a blocker — don't explore blindly or resolve it on your own.
2. **Don't run git commands.** Ever.
3. **Don't modify** CONTEXT.md or method state files.
4. **Don't make design decisions**: doubts go back to the parent in the
   report, and if they're decisions, from the parent to the human.
5. Verify with the commands from the brief's "Definition of done" and return
   the report in the required format (max ~30 lines).

## Subagent catalog

Rule v3.1: the work subagents are **generic-role and stack-agnostic** — they
detect the repo's stack and read its conventions from the `CLAUDE.local.md`.
One is **not** defined per stack (that tied the method to NestJS/React and
left out any other language, e.g. a Python repo). The native roles come
integrated and aren't maintained:

| Role | Covered by | Notes |
|---|---|---|
| Search, read, summarize, verify state | **Explore** (native subagent, read-only) | Optimized for sweeps: reads excerpts, not whole files |
| Review a diff against conventions | **/code-review** (native) | Multi-level; needs no own definition |

The work ones are defined **once at the personal level** in
`~/.claude/agents/<name>.md` — available in all your projects without adding
anything to the team's repos:

| Subagent | Role | Level/model | Tools |
|---|---|---|---|
| `implementer` | Implement per brief, in **any stack** (it detects it) | Implementer (Sonnet) | Read, Edit, Write, Bash, Glob, Grep |
| `tester` | Write and run the brief's tests, in **any framework** | Implementer (Sonnet) | Read, Edit, Write, Bash, Glob, Grep |

## Definition example — `~/.claude/agents/implementer.md`

```markdown
---
name: implementer
description: Implements a code task from a task brief, in ANY stack. Detects the repo's stack and follows its conventions.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
---

You are a stack-agnostic implementer. First step ALWAYS: detect the stack
from its manifests (package.json, pyproject.toml, Cargo.toml, go.mod,
*.xcodeproj…) and read the conventions from the repo's CLAUDE.local.md. Only
then implement, mimicking the neighboring code's patterns.

Fixed rules:
- Work ONLY within the brief's scope; if something is missing, report it as a
  blocker, don't resolve it on your own.
- Don't run git commands. Don't modify CONTEXT.md or state files.
- Don't make design decisions: doubts go in the report.
- Before finishing, run the "Definition of done" commands and paste the
  literal result in the report.
- Report (max ~30 lines): detected stack, files touched (1 line each),
  verification (command + result), findings, doubts/blockers.
```

The same mold serves `tester` — the description and focus change (detect the
test framework and mimic the style of the neighboring tests).

## Cycle per task

```
parent takes the next task from the approved plan
  └─ inline or delegate? (README §5.4)
       └─ delegate: brief → subagent (model per MODEL-ROUTING.md)
            └─ report → parent VERIFIES the evidence (build/test)
                 ├─ green → updates CONTEXT.md → commit message → next
                 └─ fail/doubts → fix the brief or ESCALATE the model
                                   (MODEL-ROUTING.md) and re-dispatch
```

## Parallelism

- Two or more **independent tasks with no shared files** can be dispatched in
  parallel.
- **Never** two subagents on the same files at the same time.
- The parent integrates the reports **sequentially**, verifying after each
  integration (not at the end of all of them).

## Security rules

- Subagents operate under the same project permissions (the README §5.1
  policy applies equally to all).
- The plan is still approved by the human BEFORE any dispatch: multi-agent
  doesn't skip the plan-mode gate.
- If a subagent returns doubts or blockers, they go up to the parent; if
  they're design decisions, they go up to the human. No one decides downward.
