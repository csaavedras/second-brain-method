<!--
  TEMPLATE — copy the block below ONCE to ~/.claude/commands/kickoff.md and
  fill in <vault-path> and <method-path>.
  The "master prompt → running project" flow: registration (/new-project) +
  persisted brief + derived brain + first plan in plan mode.
  The master prompt structure: PROJECT-BRIEF.template.md.
-->
<!-- method-version: 3.2 -->

# /kickoff — kick off a project from the master prompt

Content for `~/.claude/commands/kickoff.md`:

````markdown
---
description: Kick off a project from the master prompt — register + brain + first plan
argument-hint: [name] [path to brief, or paste it in the message]
---

Kick off this project from the MASTER PROMPT. Arguments: $ARGUMENTS

**Brief source**, in this order: (a) a file path in the arguments, (b) text
pasted in this message, (c) if neither → complete it with me **question by
question** following the structure of `<method-path>/PROJECT-BRIEF.template.md`
(one section at a time, with examples; the ones I don't know stay
"TO DECIDE").

## Step 1 — Register the project (if needed)

If this repo has no `CLAUDE.local.md`: first read and run the steps of
`~/.claude/commands/new-project.md` (pre-checks included). If it's already
registered, continue directly.

## Step 2 — Persist the master prompt

Save it as `<vault>/projects/<name>/brief.md` with the template's frontmatter
(`type: brief`, `project`, `date`, `status: current`). It's the source of
truth of the vision: it isn't rewritten — if the vision changes, it's amended
with a date.

## Step 3 — Derive the brain from the brief

- `hub.md`: "What it is" ← Vision (§1); "Stack" ← the **fixed** items of §6.
- `CONTEXT.md`: "Task summary" ← MVP scope (§4) + Out of scope (§5); "Open
  questions" ← Risks and doubts (§9); "⭐ NEXT SESSION" ← "approve the MVP
  plan".
- `decisions/`: **one note per decision already fixed** in §6 (e.g. the
  stack), with the rationale the brief gives. "TO DECIDE" items do **not**
  produce a note: they stay as open questions.

## Step 4 — First plan (plan mode)

1. If there are §9 doubts that **block** the plan, ask me first.
2. Enter **plan mode** and propose the MVP plan: short, verifiable phases,
   derived from the Scope (§4) and the Success criteria (§8). The first phase
   always ends in something that runs (walking skeleton).
3. On approval: save it in `plans/<YYYY-MM-DD>-mvp.md` and reference it from
   CONTEXT.md's todo list (don't duplicate the steps).

## Fixed rules

- The brief's "TO DECIDE" items are design decisions → resolved with me,
  never invent them.
- No git without my approval (including `git init` if the repo is new).
- When done, report: brief saved, notes created, plan approved, and the
  reminder to close with /close.
````
