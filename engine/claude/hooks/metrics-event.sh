#!/bin/bash
# Method hook (SessionStart / SubagentStop / Stop): appends one telemetry
# event line to the vault's metrics/events.jsonl. Silent, always exit 0 —
# telemetry never blocks the flow. Repos without CLAUDE.local.md log nothing.
# Usage: metrics-event.sh session-start | metrics-event.sh subagent-stop | metrics-event.sh stop
set -u
EVENT="${1:-}"
INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

# Only applies to projects where the method is instantiated
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

# Locate the vault's CONTEXT.md from the repo's CLAUDE.local.md.
# Vault-name-agnostic: matches any path ending in <vault>/projects/<p>/CONTEXT.md.
CONTEXT=$(grep -oE '[~/][^ `)]*/projects/[^ `)]*CONTEXT\.md' "$CWD/CLAUDE.local.md" 2>/dev/null | head -1)
CONTEXT="${CONTEXT/#\~/$HOME}"
{ [ -n "$CONTEXT" ] && [ -f "$CONTEXT" ]; } || exit 0

PROJDIR=$(dirname "$CONTEXT" 2>/dev/null)
[ -n "$PROJDIR" ] && [ -d "$PROJDIR" ] || exit 0

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

mkdir -p "$PROJDIR/metrics" 2>/dev/null || exit 0

jq -nc \
  --arg event "$EVENT" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson epoch "$(date +%s)" \
  --arg sid "$SESSION_ID" \
  '{event: $event, ts: $ts, epoch: $epoch, session_id: $sid}' \
  >> "$PROJDIR/metrics/events.jsonl" 2>/dev/null

exit 0
