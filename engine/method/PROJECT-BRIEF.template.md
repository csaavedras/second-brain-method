<!--
  TEMPLATE — the MASTER PROMPT of a project. Filled in ONCE at kickoff (by
  hand, or with the agent question by question via the kickoff workflow) and persisted in
  <vault>/projects/<project>/brief.md.
  It's the source of truth of the VISION: not rewritten, amended.
  Quality rule: if you don't know a section, write "TO DECIDE" — that gets
  resolved with the agent in plan mode, not invented.
-->
<!-- method-version: 4.0 -->

---
type: brief
project: <project>
date: <YYYY-MM-DD>
status: current
---

# MASTER PROMPT — <project name>

## 1. Vision
<!-- Elevator pitch: 2-3 lines. What it is and for whom. If you can't say it
     in 3 lines, it's not clear yet. -->
<...>

## 2. Problem
<!-- What hurts today and why it's worth solving. Without a real problem,
     the project dies in week 2. -->
<...>

## 3. Users
<!-- Who uses it and in what context (just you? public? mobile/desktop?).
     It changes EVERYTHING: auth, deploy, UI. -->
<...>

## 4. MVP scope
<!-- What the v1 DOES. Between 3 and 7 features, each VERIFIABLE (that can be
     demonstrated). Numbered: the MVP plan comes from here. -->
1. <...>
2. <...>
3. <...>

## 5. Out of scope (v1)
<!-- What the v1 does NOT do, even if it hurts. As important as point 4:
     it's the brake against scope creep. -->
- <...>

## 6. Stack and constraints
<!-- Separate the FIXED from the TO DECIDE: -->
- **Fixed:** <technologies you already chose and why — e.g. TS + React
  because it's your stack>
- **To decide:** <what you want to resolve with the agent in plan mode —
  e.g. SQLite or Postgres? deploy where?>
- **Constraints:** <budget $0, local only, must run on X, etc.>

## 7. Data and entities
<!-- The domain's nouns and their rough relationships. It's not the schema:
     it's the vocabulary. E.g. User has N Accounts; Account has N
     Transactions; Transaction belongs to a Category. -->
- <...>

## 8. Success criteria
<!-- How you know the MVP is DONE. Measurable and honest.
     E.g. "I log my month's expenses in <2 min and see the total by category". -->
- <...>

## 9. Risks and open questions
<!-- What you don't know yet (technical or product). They go straight to
     CONTEXT.md's "Open questions" and are resolved before or during the
     plan. -->
- <...>

## 10. References
<!-- Similar apps, designs you like, docs, inspiration repos. -->
- <...>
