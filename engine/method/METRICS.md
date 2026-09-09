<!-- Method guide — lives in this folder, not copied into projects. -->
<!-- method-version: 4.0 -->

# METRICS.md — Method telemetry (durations, tokens, estimates)

## Why

Estimating ("pointing") and improving the method both need data, not vibes:
how long a task really took, where the tokens went, how close the estimate
was. The method captures this at its existing ritual boundaries — zero new
ceremonies, ~5 seconds of human input per closed task.

## How it's captured (three layers)

1. **Hook events** (`metrics-event.sh`, registered on SessionStart /
   SubagentStop / Stop): appends `{event, ts, session_id}` lines to
   `<vault>/projects/<project>/metrics/events.jsonl`. Silent, always exit 0
   — **telemetry never blocks the flow**. Repos without `CLAUDE.local.md`
   log nothing.
2. **Per-task collection** (`scripts/collect-metrics.sh`, invoked by
   `/close`): parses the session transcript (`~/.claude/projects/…/*.jsonl`)
   with `jq` — token usage per model, parent vs. sidechain (subagents) —
   and crosses it with `events.jsonl` for durations. The human adds two
   fields at close: `type` and `estimate`.
3. **Rollup** (`scripts/brain-metrics.sh`, run weekly like
   `brain-health.sh`): aggregates all projects' `metrics.jsonl` — 0 LLM
   tokens.

## Schema — one line per closed task in `metrics/metrics.jsonl`

```json
{
  "date": "YYYY-MM-DD",
  "session_id": "…",
  "task": "short task title",
  "type": "feat | bug | refactor | spike",
  "estimate": "3pt | 2h | null",
  "duration": { "total_min": 0, "plan_min": 0, "exec_min": 0 },
  "subagents": [ { "role": "implementer", "model": "sonnet", "duration_s": 0 } ],
  "tokens": {
    "in": 0, "out": 0, "cache_read": 0,
    "by_model": { "<model-id>": { "in": 0, "out": 0 } },
    "parent": { "in": 0, "out": 0 },
    "subagents_total": { "in": 0, "out": 0 }
  }
}
```

Notes on semantics:

- `duration.plan_min`: session start → first plan approval (refinement
  phase); `exec_min` = the rest. Derived from event timestamps — exact.
- `type` and `estimate` come from the human at `/close` — they are what
  makes the data comparable with agile pointing. `estimate: null` is fine;
  a wrong guess recorded honestly beats a blank.
- Fields the collector can't compute (e.g. no events file) are `null`, and
  the line is still written: partial data > no data.

## Reading the data

`brain-metrics.sh` reports per project and overall:

- tokens/task and duration by `type` (what does a "bug" cost vs. a "feat"?)
- estimate vs. actual (your pointing accuracy over time)
- parent vs. subagent token split (is delegation actually saving?)
- month-over-month evolution (is the method getting cheaper/faster?)

The jsonl files are data, not notes: no frontmatter, excluded from
`brain-health.sh` checks (it only scans `*.md`), and trivially exportable
to any dashboard later (the schema is flat enough for `jq`/DuckDB).

## What we deliberately don't do

- No OpenTelemetry/collector infra: right 90% of the value at 0 infra.
  The jsonl migrates trivially if that day comes.
- No cost-in-dollars column: prices change and depend on plan; tokens and
  models are the stable ground truth. Compute cost at read time if needed.
