<!-- Method guide — lives in this folder, not copied into projects. -->
<!-- method-version: 4.0 -->

# SKILLS-REGISTRY.md — Curated skill selection for dispatches

## The principle

Skills are cheap to keep installed (an unused skill costs ~1 index line) but
expensive to pick badly: a subagent loaded with the wrong skill follows the
wrong playbook. The method's rule:

> **Dynamic selection from a curated local registry — never dynamic external
> search.** The orchestrator consults this registry when writing a task brief
> and names **0–2 skills** in the brief's "Skills to use" section. Fetching or
> installing skills from the internet at dispatch time is forbidden: it adds
> latency, non-determinism and a real supply-chain risk (executing playbook
> instructions nobody curated).

The subagents (`implementer`, `tester`) carry the `Skill` tool and invoke
**only** the skills named in their brief — they don't browse the catalog.

## The registry

One row per skill you have installed and vetted. Keep it honest: this table
is what the orchestrator reads at dispatch time.

| Skill | Use it when | Stacks / tasks |
|---|---|---|
| `verify` | The change has a runtime surface and must be exercised end-to-end, not just tested | any |
| `code-review` | Reviewing a diff for correctness + practices + efficiency (parent runs it, via `/gate`) | any |
| `security-review` | The diff touches auth, input handling, crypto, deps or network (parent runs it, via `/gate`) | any |
| `dataviz` | The task produces a chart, dashboard or data visualization | frontend, notebooks, reports |
| `frontend-design` | Building UI that must look intentional, not default | web frontend |
| `test-driven-development` | The brief asks for tests-first workflow | any |
| <add yours> | <one line: the trigger, not the description> | <where it applies> |

Rows marked "parent runs it" are gate lenses — they are never named in a
subagent brief; the parent invokes them directly during `/gate`.

## Curation rules

1. **Add on first real use.** A skill enters the registry the first time it
   actually earned its place in a task — with a one-line trigger written by
   you, not copied from its description.
2. **Prune on disuse.** A skill that hasn't fired in **~10 sessions** leaves
   the table (the skill can stay installed; it just stops being dispatch
   material). Review during vault maintenance, e.g. when running
   `brain-health.sh`.
3. **One trigger line per skill.** If you can't state in one line *when* it
   applies, you don't know the skill well enough to route work to it.
4. **The registry lives in the vault** (`<vault>/method/SKILLS-REGISTRY.md`)
   — it's personal curation, like the rest of the brain.

## How it's exercised

```
parent writes a task brief
  └─ consults this table: does any trigger match the task?
       ├─ no  → "Skills to use" is omitted (most tasks)
       └─ yes → names 0–2 skills + one line of why, e.g.:
                 "- test-driven-development — brief asks for tests-first"
            └─ subagent invokes ONLY those, via its Skill tool
```

Naming more than 2 skills in a brief is a smell: the task is probably too big
— split the brief instead.
