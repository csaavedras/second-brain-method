<!--
  TEMPLATE — the parent agent fills it for EACH subagent dispatch.
  The brief is ephemeral: it lives in the dispatch prompt, not copied to the
  repo. Briefs worth reusing are saved in the brain (briefs/).
  Quality rule: the subagent should NOT need anything outside this brief.
  See MULTI-AGENT.md and MODEL-ROUTING.md.
-->
<!-- method-version: 3.2 -->

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
<!-- E.g. frontend-design, test-driven-development. Omit if not applicable. -->
- <...>

## Definition of done
<!-- Verification commands that must pass green: -->
- `<test/build/lint command>` green

## Constraints (method-fixed — do not edit)
- Work ONLY within this brief's scope; if something is missing, report it as
  a blocker, don't resolve it on your own.
- Don't run git commands. Don't modify CONTEXT.md or state files.
- Don't make design decisions: doubts come back in the report.

## Report format (mandatory, max ~30 lines)
1. Files touched and what changed in each (1 line per file)
2. Verification: command run + literal result
3. Findings (if any)
4. Doubts / blockers (if any)
