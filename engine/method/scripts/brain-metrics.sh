#!/bin/bash
# brain-metrics — rollup of task metrics across all projects (0 LLM tokens).
# Aggregates each project's metrics/metrics.jsonl (one line per closed task,
# written by /close via collect-metrics.sh) into a human-readable report:
# duration & tokens by task type, estimate-vs-actual, parent-vs-subagent
# token split, and month-over-month evolution. See METRICS.md for the
# schema. Malformed lines are skipped and counted, never fatal.
# Usage: brain-metrics.sh [vault-path]
set -u
VAULT="${1:-@@VAULT@@}"
[ -d "$VAULT" ] || { printf '@@MSG_METRICS_ERR_NO_VAULT@@\n' "$VAULT"; exit 2; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

printf '@@MSG_METRICS_HEADER@@\n' "$VAULT"

# ── Discover metrics.jsonl files ─────────────────────────────────────────────
find "$VAULT" -path "$VAULT/projects/*/metrics/metrics.jsonl" -type f 2>/dev/null | sort > "$TMP/files"
NFILES=$(wc -l < "$TMP/files" | tr -d ' ')

if [ "$NFILES" -eq 0 ]; then
  printf '@@MSG_METRICS_NO_METRICS_YET@@\n'
  exit 0
fi

# ── Split each project's lines into valid JSON vs malformed (skip + count) ──
MALFORMED=0
: > "$TMP/all.jsonl"
: > "$TMP/projects"
while IFS= read -r f; do
  proj=$(basename "$(dirname "$(dirname "$f")")")
  echo "$proj" >> "$TMP/projects"
  : > "$TMP/proj-$proj.jsonl"
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$TMP/proj-$proj.jsonl"
      printf '%s\n' "$line" >> "$TMP/all.jsonl"
    else
      MALFORMED=$((MALFORMED + 1))
    fi
  done < "$f"
done < "$TMP/files"
sort -u "$TMP/projects" -o "$TMP/projects"

TOTAL_TASKS=$(wc -l < "$TMP/all.jsonl" | tr -d ' ')
printf '@@MSG_METRICS_SUMMARY@@\n' "$NFILES" "$TOTAL_TASKS"

# ── jq report filter: one program, reused for overall + each project ────────
# User-visible text comes in as --arg strings (see call sites below), never
# hardcoded here. fmt() fills %s placeholders by splitting on the literal
# "%s" marker (never a regex substitution) so an arg value can never be
# misinterpreted as part of the template; %% in the template collapses to a
# literal % once the split is done (so it can never eat into arg values).
JQ_FILTER='
def fmt($tmpl; $args):
  ($tmpl | split("%s") | map(gsub("%%"; "%"))) as $parts
  | if ($parts | length) != (($args | length) + 1) then $tmpl
    else reduce range(0; $args | length) as $i
           ($parts[0]; . + ($args[$i] | tostring) + $parts[$i + 1])
    end;

def avgf(f):
  (map(f) | map(select(. != null))) as $vals
  | if ($vals | length) > 0 then (($vals | add) / ($vals | length)) else null end;

def round1:
  if . == null then null else ((. * 10 | round) / 10) end;

. as $items
| ($items | length) as $n
| if $n == 0 then
    $no_tasks
  else
    ( $items | group_by(.type) | map({
        type: (.[0].type // "unknown"),
        count: length,
        avg_total: (avgf(.duration.total_min) | round1),
        avg_tokens: (avgf((.tokens.in // 0) + (.tokens.out // 0)) | round1)
      }) | sort_by(.type)
    ) as $by_type
    | ( $items | map(select(.estimate != null)) ) as $with_est
    | ( $items | map((.tokens.parent.in // 0) + (.tokens.parent.out // 0)) | add // 0) as $parent_tok
    | ( $items | map((.tokens.subagents_total.in // 0) + (.tokens.subagents_total.out // 0)) | add // 0) as $side_tok
    | ( $parent_tok + $side_tok ) as $total_tok
    | ( $items | group_by(.date[0:7] // "unknown") | map({
        month: (.[0].date[0:7] // "unknown"),
        tasks: length,
        tokens: (map((.tokens.in // 0) + (.tokens.out // 0)) | add // 0)
      }) | sort_by(.month)
    ) as $by_month
    | (
        fmt($tasks_line; [$n]) + "\n"
        + "\n   " + $by_type_hdr + "\n"
        + ( $by_type
            | map(fmt($by_type_item; [.type, .count, (.avg_total // $na), (.avg_tokens // $na)]))
            | join("\n")
          ) + "\n"
        + "\n   " + $est_hdr + "\n"
        + ( if ($with_est | length) == 0 then $no_est
            else ( $with_est
                   | map(fmt($est_item; [(.task // "?"), .estimate, (.duration.total_min // $na)]))
                   | join("\n")
                 )
            end
          ) + "\n"
        + "\n   " + $tokens_hdr + "\n"
        + fmt($tokens_parent; [$parent_tok, (if $total_tok > 0 then (($parent_tok*100/$total_tok)|round) else 0 end)]) + "\n"
        + fmt($tokens_subagents; [$side_tok, (if $total_tok > 0 then (($side_tok*100/$total_tok)|round) else 0 end)]) + "\n"
        + "\n   " + $month_hdr + "\n"
        + ( $by_month
            | map(fmt($month_item; [.month, .tasks, .tokens]))
            | join("\n")
          )
      )
  end
'

# ── Overall report ───────────────────────────────────────────────────────────
echo
printf '@@MSG_METRICS_OVERALL_TITLE@@\n'
jq -s -r "$JQ_FILTER" \
  --arg no_tasks '@@MSG_METRICS_NO_TASKS@@' \
  --arg tasks_line '@@MSG_METRICS_TASKS_LINE@@' \
  --arg by_type_hdr '@@MSG_METRICS_BY_TYPE_HDR@@' \
  --arg by_type_item '@@MSG_METRICS_BY_TYPE_ITEM@@' \
  --arg est_hdr '@@MSG_METRICS_EST_HDR@@' \
  --arg no_est '@@MSG_METRICS_NO_EST@@' \
  --arg est_item '@@MSG_METRICS_EST_ITEM@@' \
  --arg tokens_hdr '@@MSG_METRICS_TOKENS_HDR@@' \
  --arg tokens_parent '@@MSG_METRICS_TOKENS_PARENT@@' \
  --arg tokens_subagents '@@MSG_METRICS_TOKENS_SUBAGENTS@@' \
  --arg month_hdr '@@MSG_METRICS_MONTH_HDR@@' \
  --arg month_item '@@MSG_METRICS_MONTH_ITEM@@' \
  --arg na '@@MSG_METRICS_NA@@' \
  "$TMP/all.jsonl"

# ── Per-project report ───────────────────────────────────────────────────────
while IFS= read -r proj; do
  [ -z "$proj" ] && continue
  echo
  printf '@@MSG_METRICS_PROJECT_TITLE@@\n' "$proj"
  jq -s -r "$JQ_FILTER" \
    --arg no_tasks '@@MSG_METRICS_NO_TASKS@@' \
    --arg tasks_line '@@MSG_METRICS_TASKS_LINE@@' \
    --arg by_type_hdr '@@MSG_METRICS_BY_TYPE_HDR@@' \
    --arg by_type_item '@@MSG_METRICS_BY_TYPE_ITEM@@' \
    --arg est_hdr '@@MSG_METRICS_EST_HDR@@' \
    --arg no_est '@@MSG_METRICS_NO_EST@@' \
    --arg est_item '@@MSG_METRICS_EST_ITEM@@' \
    --arg tokens_hdr '@@MSG_METRICS_TOKENS_HDR@@' \
    --arg tokens_parent '@@MSG_METRICS_TOKENS_PARENT@@' \
    --arg tokens_subagents '@@MSG_METRICS_TOKENS_SUBAGENTS@@' \
    --arg month_hdr '@@MSG_METRICS_MONTH_HDR@@' \
    --arg month_item '@@MSG_METRICS_MONTH_ITEM@@' \
    --arg na '@@MSG_METRICS_NA@@' \
    "$TMP/proj-$proj.jsonl"
done < "$TMP/projects"

echo
if [ "$MALFORMED" -gt 0 ]; then
  printf '@@MSG_METRICS_MALFORMED@@\n' "$MALFORMED"
else
  printf '@@MSG_METRICS_CLEAN@@\n'
fi
exit 0
