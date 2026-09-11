<!--
  TEMPLATE — the parent agent fills it for EACH subagent dispatch.
  The brief is ephemeral: it lives in the dispatch prompt, not copied to the
  repo. Briefs worth reusing are saved in the brain (briefs/).
  Quality rule: the subagent should NOT need anything outside this brief.
  See MULTI-AGENT.md and MODEL-ROUTING.md.
-->
<!-- method-version: 4.0 -->

# TASK BRIEF — <short task title>

## Goal
<!-- 1-3 lines: what must exist/work when you finish. -->
<...>

## Minimal context
<!-- Only what's needed: what the project is in 2 lines + the design decision
     relevant to THIS task, if any. Do NOT paste the whole CONTEXT.md. -->
<...>

## Relevant files
<!-- Concrete paths with the why. The subagent doesn't explore blindly. -->
- `<path>` — <why it's relevant>

## Conventions to follow
<!-- Pointed pointers, not "read all the docs": -->
- Read `<docs/0X-...>.md` and follow that pattern for <...>

## Skills to use
<!-- 0-2 skills picked from the registry (SKILLS-REGISTRY.md), each with one
     line of why. Omit if none applies — most tasks need none. -->
- <skill> — <why it applies to THIS task>

## Acceptance criteria
<!-- Two blocks. The subagent is NOT done until every item has evidence. -->
Commands (must pass green):
- `<test/build/lint command>` green

Observable behavior:
<!-- Concrete, checkable statements — "returns 404 when X", "logs the error
     with context", "the flag defaults to off". Not vibes. -->
- <...>

## Constraints (method-fixed — do not edit)
- Work ONLY within this brief's scope; if something is missing, report it as
  a blocker, don't resolve it on your own.
- Don't run git commands. Don't modify CONTEXT.md or state files.
- Don't make design decisions: doubts come back in the report.
- Invoke only the skills named above; don't pick skills on your own.

## Report format (mandatory, max ~30 lines)
1. Detected stack/framework + conventions followed (1-2 lines)
2. Files touched and what changed in each (1 line per file)
3. Verification — one line per command, EXACTLY this shape (the harness
   checks it): ``Verification: `<command>` → <literal result>``
4. Criteria evidence: each acceptance criterion → its evidence (1 line each)
5. Findings (if any)
6. Doubts / blockers (if any)
