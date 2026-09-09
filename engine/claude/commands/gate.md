---
description: Risk-based pre-commit gate — review lenses, fix cycle, READY/NOT-READY verdict
---

Run the method's quality gate on the current working diff, BEFORE leaving a
commit message. Skip entirely (and say so) if the diff has no runtime
surface (docs, comments, method notes).

## 1. Classify the diff

Look at the touched paths and content, and classify (a diff can be both):

- **Sensitive** — touches auth/session handling, input parsing/validation,
  crypto, dependency changes (lockfiles, manifests), network calls, file
  system or process execution, secrets handling.
- **Perf-relevant** — touches hot paths, DB queries, loops over datasets,
  caching, concurrency.
- **Normal** — everything else.

State the classification in one line before running anything.

## 2. Run the lenses that apply

- **Always**: `/code-review` — effort scales with the diff (small diff →
  low/medium; large or subtle → high). For a large MR-sized branch, suggest
  `/code-review ultra` to the human instead of burning the session.
- **Sensitive**: additionally `/security-review`.
- **Perf-relevant**: an optimization pass ONLY with evidence — measure
  (profile, EXPLAIN, timing) before claiming a finding. No speculative
  micro-optimization findings; an unmeasured perf opinion is not a finding.
- **Project checklist**: if `~/second-brain/projects/<project>/review-checklist.md`
  exists, check the diff against each of its rules — these are distilled
  from real MR comments this project received; they outrank generic taste.

## 3. Triage

The parent triages every finding:

- Only **confirmed** findings (reproducible failure scenario, or a checklist
  rule verifiably violated) become fixes. Plausible-but-unverified ones are
  listed in the verdict as notes, not acted on.
- Confirmed findings → fix briefs → `implementer` → re-verify the evidence.
  **Max 2 fix cycles** (MULTI-AGENT.md); on the third the diagnosis goes up
  to the human.

## 4. Verdict (mandatory, last line of the gate)

```
GATE: READY            — lenses run, no confirmed findings open
GATE: NOT-READY — <n> confirmed finding(s) open: <one line each>
```

Only **READY** enables leaving the commit message. NOT-READY at the cycle
cap → present the open findings to the human and stop; never "READY with
caveats".

Rules: the gate runs on the **integrated** diff (after merging subagent
work), never per subagent. The gate itself makes no design decisions —
findings that imply one go to the human.
