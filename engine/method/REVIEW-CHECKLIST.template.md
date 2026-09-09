<!--
  TEMPLATE — instantiated as <vault>/projects/<project>/review-checklist.md
  the first time /learn review captures an MR comment for the project.
  Loaded by /gate on every run: these rules outrank generic review taste
  because they are distilled from comments THIS project actually received.
  Rule quality: checkable in one look at a diff. If a rule needs judgment
  ("code should be clean"), it doesn't belong here — distill it further.
-->
<!-- method-version: 4.0 -->
---
type: checklist
project: <project>
date: <YYYY-MM-DD>
tags: [review]
---

# Review checklist — <project>

One rule per line: **what to check** ← *origin (the real MR comment, dated)*.

## Rules

- <what to check, concretely — e.g. "every new endpoint validates params
  before use"> ← <YYYY-MM-DD, MR #NN: "the reviewer's actual comment">

## Retired rules
<!-- Rules that stopped applying (stack change, team convention change).
     Keep them: they document why they left. -->
