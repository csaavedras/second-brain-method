#!/bin/bash
# brain-metrics — rollup of task metrics across all projects (0 LLM tokens).
# Aggregates each project's metrics/metrics.jsonl (one line per closed task,
# written by /close via collect-metrics.sh) into a human-readable report:
# duration & tokens by task type, estimate-vs-actual, parent-vs-subagent
# token split, and month-over-month evolution. See METRICS.md for the
# schema. Malformed lines are skipped and counted, never fatal.
# Usage: brain-metrics.sh [vault-path]
set -u
VAULT="${1:-$HOME/second-brain}"
[ -d "$VAULT" ] || { echo "ERROR: vault does not exist: $VAULT"; exit 2; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "🧠 brain-metrics — $VAULT"

# ── Discover metrics.jsonl files ─────────────────────────────────────────────
find "$VAULT" -path "$VAULT/projects/*/metrics/metrics.jsonl" -type f 2>/dev/null | sort > "$TMP/files"
NFILES=$(wc -l < "$TMP/files" | tr -d ' ')

if [ "$NFILES" -eq 0 ]; then
  echo "   No metrics yet — close a task with /close to start recording."
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
echo "   Projects: $NFILES   Tasks: $TOTAL_TASKS"

# ── jq report filter: one program, reused for overall + each project ────────
JQ_FILTER='
def avgf(f):
  (map(f) | map(select(. != null))) as $vals
  | if ($vals | length) > 0 then (($vals | add) / ($vals | length)) else null end;

def round1:
  if . == null then null else ((. * 10 | round) / 10) end;

. as $items
| ($items | length) as $n
| if $n == 0 then
    "   (no tasks recorded yet)"
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
        "   Tasks: \($n)\n"
        + "\n   By type:\n"
        + ( $by_type
            | map("     - \(.type): \(.count) task(s), avg total \(.avg_total // "n/a")min, avg tokens \(.avg_tokens // "n/a")")
            | join("\n")
          ) + "\n"
        + "\n   Estimate vs actual:\n"
        + ( if ($with_est | length) == 0 then "     (no estimates recorded)"
            else ( $with_est
                   | map("     - \(.task // "?"): \(.estimate) → \(.duration.total_min // "n/a")min")
                   | join("\n")
                 )
            end
          ) + "\n"
        + "\n   Parent vs subagents tokens:\n"
        + "     - parent: \($parent_tok) (\(if $total_tok > 0 then (($parent_tok*100/$total_tok)|round) else 0 end)%)\n"
        + "     - subagents: \($side_tok) (\(if $total_tok > 0 then (($side_tok*100/$total_tok)|round) else 0 end)%)\n"
        + "\n   Month over month:\n"
        + ( $by_month
            | map("     - \(.month): \(.tasks) task(s), \(.tokens) tokens")
            | join("\n")
          )
      )
  end
'

# ── Overall report ───────────────────────────────────────────────────────────
echo
echo "── Overall ──────────────────────────────────────────"
jq -s -r "$JQ_FILTER" "$TMP/all.jsonl"

# ── Per-project report ───────────────────────────────────────────────────────
while IFS= read -r proj; do
  [ -z "$proj" ] && continue
  echo
  echo "── Project: $proj ───────────────────────────────────"
  jq -s -r "$JQ_FILTER" "$TMP/proj-$proj.jsonl"
done < "$TMP/projects"

echo
if [ "$MALFORMED" -gt 0 ]; then
  echo "⚠️  $MALFORMED malformed line(s) skipped"
else
  echo "✅ Report complete — no malformed lines"
fi
exit 0
