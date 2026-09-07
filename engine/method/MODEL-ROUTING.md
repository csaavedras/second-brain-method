<!-- method-version: 4.0 -->

# Model routing by capability

Use the cheapest model/effort with sufficient capability. The human sets the main
session configuration; no frontier model is a dependency of the method.

| Semantic role | Work | Configuration |
|---|---|---|
| Explorer | Bounded search, reading, summaries | Fast/low-cost, read-heavy |
| Implementer | Approved implementation or bounded refactor | Balanced coding |
| Reasoner | Architecture, difficult debugging, tradeoffs, review | Strong reasoning when needed |
| Tester | Verify DoD, test behaviors, identify regressions | Sufficient test/debug capability |

Provider examples are configurable, not requirements: Claude can use fast,
balanced and strongest reasoning model tiers. Codex can use lower-cost/faster
models or lower effort for exploration, balanced coding for implementation and
high effort/strong reasoning for difficult decisions. Names belong in adapter or
personal runtime configuration, not semantic rules. Distributed Codex agents
inherit the parent's configured model and effort so they remain usable as names
change; users may override those fields in their backed-up personal agent files.

If verification fails or a worker reports uncertainty, refine the brief and
escalate capability. Two failures at the same level require checking the brief.
Do not downgrade mid-task to try to hide failure.

Keep the main session's model, effort, instructions and tool surface stable when
practical for cache efficiency. Change configuration at a close → new-session
boundary. Provider cache behavior differs; don't promise fixed token savings.
Each worker has a bounded separate context.

Prefer closing and reopening after a completed task. Compact only after persisting
unfinished state; use an isolated session/branch for experiments, with the usual
Git authorization. Clearing a conversation never substitutes for saving context.
