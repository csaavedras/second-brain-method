#!/bin/bash
# collect-metrics.sh — per-task metrics collector (0 LLM tokens).
# Parses a Claude Code session transcript (JSONL) and an optional hook
# events file (metrics-event.sh output) and emits ONE compact JSON metrics
# object on stdout, matching METRICS.md's schema minus the human fields
# (task/type/estimate — the caller, /close, merges those in).
# Missing pieces become null fields: partial data beats no data.
# Usage: collect-metrics.sh <transcript.jsonl> [events.jsonl]
set -u

if [ $# -lt 1 ]; then
  echo "Usage: collect-metrics.sh <transcript.jsonl> [events.jsonl]" >&2
  exit 2
fi

TRANSCRIPT="$1"
EVENTS="${2:-}"

[ -f "$TRANSCRIPT" ] || { echo "ERROR: transcript not found: $TRANSCRIPT" >&2; exit 2; }

SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)
TODAY=$(date +%Y-%m-%d)

# --slurpfile needs a real, readable file — fall back to an empty one when
# events.jsonl was not given or does not exist yet.
EVENTS_FILE="$EVENTS"
TMP_EVENTS=""
if [ -z "$EVENTS_FILE" ] || [ ! -f "$EVENTS_FILE" ]; then
  TMP_EVENTS=$(mktemp)
  EVENTS_FILE="$TMP_EVENTS"
fi
trap '[ -n "$TMP_EVENTS" ] && rm -f "$TMP_EVENTS"' EXIT

# One jq program does the heavy lifting: token sums, per-model breakdown,
# sidechain (subagent) segmentation and duration math, all in a single pass.
JQ_FILTER='
def toepoch: sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime;

. as $lines
| ($lines | map(select(.type=="assistant" and .message.usage != null))) as $assistant
| ($assistant | map(select(.isSidechain != true))) as $parent
| ($assistant | map(select(.isSidechain == true))) as $side

| ($parent | map((.message.usage.input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) | add // 0) as $parent_in
| ($parent | map(.message.usage.output_tokens // 0) | add // 0) as $parent_out
| ($side | map((.message.usage.input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) | add // 0) as $side_in
| ($side | map(.message.usage.output_tokens // 0) | add // 0) as $side_out
| ($assistant | map(.message.usage.cache_read_input_tokens // 0) | add // 0) as $cache_read

| ($assistant
    | group_by(.message.model)
    | map({
        key: (.[0].message.model // "unknown"),
        value: {
          in: (map((.message.usage.input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)) | add // 0),
          out: (map(.message.usage.output_tokens // 0) | add // 0)
        }
      })
    | from_entries
  ) as $by_model

# Subagent segments: group consecutive sidechain lines together. role is
# always null (the transcript does not carry which agent role ran).
| (reduce $lines[] as $l
    ({groups: [], cur: null};
      if ($l.isSidechain == true) then
        .cur = ((.cur // []) + [$l])
      else
        (if .cur != null then (.groups += [.cur]) else . end) | .cur = null
      end
    )
  | (if .cur != null then .groups += [.cur] else . end)
  | .groups
  | map({
      role: null,
      model: (([.[] | .message.model? // empty] | first) // null),
      duration_s: (
        ([.[] | .timestamp? // empty] | map(select(. != null and . != ""))) as $ts
        | if ($ts | length) >= 2 then
            (($ts[-1] | toepoch) - ($ts[0] | toepoch))
          else 0 end
      )
    })
  ) as $subagents

| ($lines | map(.timestamp? // empty) | map(select(. != null and . != ""))) as $all_ts
| (if ($all_ts | length) > 0 then ($all_ts[0] | toepoch) else null end) as $transcript_start
| (if ($all_ts | length) > 0 then ($all_ts[-1] | toepoch) else null end) as $transcript_end

| $events as $ev
| (($ev | length) > 0) as $has_events
| ($ev | map(select(.event=="session-start")) | map(.epoch) | first) as $ev_start
| ($ev | map(select(.event=="stop")) | map(.epoch) | last) as $ev_stop_last
| ($ev | map(.epoch) | last) as $ev_any_last

| (if $has_events then $ev_start else $transcript_start end) as $start_epoch
| (if $has_events then (if $ev_stop_last != null then $ev_stop_last else $ev_any_last end) else $transcript_end end) as $end_epoch

| (if $start_epoch != null and $end_epoch != null then (($end_epoch - $start_epoch) / 60) else null end) as $total_min_raw
| (if $total_min_raw != null then ($total_min_raw | round) else null end) as $total_min

| ([$lines[] | select(.message.content[]? | select(.type=="tool_use" and .name=="ExitPlanMode")) | .timestamp] | map(select(. != null)) | first) as $plan_ts
| (if $plan_ts != null and $start_epoch != null then ((($plan_ts | toepoch) - $start_epoch) / 60) else null end) as $plan_min_raw
| (if $plan_min_raw != null then ($plan_min_raw | round) else null end) as $plan_min

| (if $plan_min != null and $total_min != null then ($total_min - $plan_min) elif $total_min != null then $total_min else null end) as $exec_min

| {
    date: $date,
    session_id: $session_id,
    duration: { total_min: $total_min, plan_min: $plan_min, exec_min: $exec_min },
    subagents: $subagents,
    tokens: {
      in: ($parent_in + $side_in),
      out: ($parent_out + $side_out),
      cache_read: $cache_read,
      by_model: $by_model,
      parent: { in: $parent_in, out: $parent_out },
      subagents_total: { in: $side_in, out: $side_out }
    }
  }
'

RESULT=$(jq -s \
  --arg session_id "$SESSION_ID" \
  --arg date "$TODAY" \
  --slurpfile events "$EVENTS_FILE" \
  "$JQ_FILTER" \
  "$TRANSCRIPT" 2>/dev/null)

# Validate our own output before printing — on internal failure, print
# nothing and fail loudly on stderr only.
if [ -z "$RESULT" ] || ! printf '%s' "$RESULT" | jq . >/dev/null 2>&1; then
  echo "ERROR: failed to compute metrics from transcript: $TRANSCRIPT" >&2
  exit 1
fi

printf '%s' "$RESULT" | jq -c .
