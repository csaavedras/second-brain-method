<!-- Method guide — lives with the method, not copied into projects. -->
<!-- method-version: 4.0 -->

# BRAIN.md — The persistent brain (Obsidian vault)

## What it is

A single, **personal** Obsidian vault that is the home of **all** the method
state for **all** projects: live context, plans, sessions, decisions and
patterns. Each project's repo keeps only simple team documentation. The vault
is pure markdown: the agent reads and writes with file tools, without plugins
or MCP (Dataview/Bases are optional, for the human's queries).

> The graph IS the brain: each note links with [[wikilinks]] to the notes that
> explain it. A decision links to its project's hub and to the pattern it
> applied; a pattern links to the decisions where it was born.

## Structure

```
<vault>/
  00-index/                 # home.md, topic MOCs and projects.json registry
  projects/<project>/
    hub.md                  # what it is, macro state, local repo path
    CONTEXT.md              # live state (see CONTEXT.template.md)
    plans/                  # approved plans for large tasks
    sessions/               # closed history: YYYY-MM-DD.md
    decisions/              # the project's design decisions
    graph/                  # optional graph notes (CLI output stays in repo)
  patterns/                 # recipes/patterns born from projects
  learning/                 # study: concepts, resources, TILs (see below)
    <topic>/                # concepts and resources of the topic
    til/                    # loose learnings: YYYY-MM-DD-<slug>.md
  briefs/                   # task briefs worth keeping
```

## Standard frontmatter

Every vault note opens with:

```yaml
---
type: hub | context | plan | session | decision | pattern | brief |
      concept | resource | til | moc
project: <project>           # omit in cross-cutting patterns and learning
date: YYYY-MM-DD
status: active | current | resolved | archived   # per type
tags: []
---
```

`type` + `project` + `date` enable the agent's grep searches and the human's
Dataview/Bases queries without opening each note.

## Naming conventions

- kebab-case; ISO date at the front when order matters.
- Decisions: `decisions/<YYYY-MM-DD>-<topic>.md`
- Sessions: `sessions/<YYYY-MM-DD>.md`
- Patterns: `patterns/<topic>.md` (no date in the name: they get updated)

## Note templates

### Hub — `projects/<project>/hub.md` (one per project)

```markdown
---
type: hub
project: <project>
date: <YYYY-MM-DD>
status: active
---
# <project>
- **What it is:** <1-2 lines>
- **Local repo:** `<absolute path>`
- **Stack:** <1 line>

## Macro state
<2-3 lines; updated when closing milestones — the detail lives in [[CONTEXT]]>

## Key decisions
- [[<YYYY-MM-DD>-<topic>]] — <1 line>

## Patterns it uses
- [[<pattern>]]
```

### Decision — `decisions/<YYYY-MM-DD>-<topic>.md`

```markdown
---
type: decision
project: <project>
date: <YYYY-MM-DD>
status: current
---
# <the decision in one line>
**Context:** <what problem there was>
**Decision:** <what was decided>
**Why:** <alternatives discarded and reason>

Related: [[hub]] · [[<pattern>]]
```

### Pattern — `patterns/<topic>.md`

```markdown
---
type: pattern
date: <YYYY-MM-DD>
tags: []
---
# <pattern>
**When it applies:** <...>
**Recipe:** <steps or minimal example>
**Origin:** [[<decision or session where it was born>]]
```

### Session — `sessions/<YYYY-MM-DD>.md`

```markdown
---
type: session
project: <project>
date: <YYYY-MM-DD>
---
# Session <YYYY-MM-DD>
**What was done:** <bullets>
**Verification:** <commands run + result>
**Decided:** [[<decision>]] <if any>
**Left pending:** <...>
```

## Learning layer (`learning/`)

The brain isn't only about projects: it also stores what you study. Three note
types, captured with the provider’s learn workflow (or by hand):

- **concept** — durable idea explained in your own words. Atomic: one idea
  per note. `learning/<topic>/<slug>.md`
- **resource** — course/book/article with progress status
  (`status: in-progress | done | dropped`). `learning/<topic>/<slug>.md`
- **til** — a single fact of the day ("today I learned"), a quick capture
  with no claim to permanence. `learning/til/<YYYY-MM-DD>-<slug>.md`

### Concept — `learning/<topic>/<slug>.md`

```markdown
---
type: concept
date: <YYYY-MM-DD>
tags: []
---
# <concept>
<explanation in your own words, 3-10 lines — a single idea>

Related: [[<topic MOC>]] · [[<other concept or pattern>]]
Source: [[<resource>]] <or URL>
```

### Resource — `learning/<topic>/<slug>.md`

```markdown
---
type: resource
date: <YYYY-MM-DD>
status: in-progress
tags: []
---
# <course / book / article>
- **What it is:** <1 line + URL>
- **Why I study it:** <1 line>

## Notes that came out of this
- [[<concept>]] — <1 line>

## Pending
- <...>
```

### TIL — `learning/til/<YYYY-MM-DD>-<slug>.md`

```markdown
---
type: til
date: <YYYY-MM-DD>
tags: []
---
# TIL: <what was learned in one line>
<minimal detail + example if it applies>

Related: [[<...>]]
```

### MOC rule

MOCs (`00-index/<topic>.md`, `type: moc`) are entry points by topic, not
exhaustive indexes. **Rule: on the third wikilink toward a topic that has no
MOC, the MOC is created** and the existing notes are linked from there. A TIL
that over time proves durable is promoted to a concept (and the original TIL
keeps a wikilink to the new note).

## How the method uses it

### On opening a session (start)
The parent reads `projects/<project>/CONTEXT.md` (+ the in-progress plan if
any). For long historical context it consults `hub.md` and follows the
wikilinks — it doesn't dig through old files.

### On closing a task (extends the close rule)
Besides updating CONTEXT.md:
- Non-obvious decision made → a note in `decisions/` + link in the hub.
- Learning reusable in other projects → a note in `patterns/`.
- The hub is updated when closing **milestones**, not on every task.

### Archiving
On completing a phase, or when CONTEXT.md exceeds ~150 lines: the closed
history moves down to a `sessions/` note and CONTEXT.md keeps only what's live
(current state, next session, todo list, current decisions, open questions).

## Security

The vault isn't versioned inside the repos, but it's usually synced (Obsidian
Sync, iCloud, private git). There too, **no** secret values, tokens or
credentials: names of variables and where to obtain them, never the values.

## Provider independence and ownership

Both adapters resolve the same `00-index/projects.json` and use the same notes.
The registry maps physical repository roots (including worktree aliases) to a
single project; see PROJECT-REGISTRY.md. No provider-specific state copy exists.
`Claude /close → CONTEXT.md persisted → Codex $sb-start` resumes the same work,
and the reverse is equally valid. The parent is the sole writer of live state
unless it explicitly delegates a bounded file update and reconciles the result.

Cross-repo tasks have one owning CONTEXT in the primary project; other projects
keep their own registry mapping and link to that task. Never maintain duplicate
live states for one task. A provider switch changes the runtime, not ownership.
