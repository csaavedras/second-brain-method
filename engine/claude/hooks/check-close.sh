#!/bin/bash
# method-version: 4.0 — provider protocol only; facts live in the shared core.
set -euo pipefail
EVENT="${1:-stop}"
INPUT=$(cat)
case "$EVENT" in stop|precompact|start) ;; *) echo "Unknown event" >&2; exit 2 ;; esac
if [ "$EVENT" = stop ] && printf '%s' "$INPUT" | jq -e '.stop_hook_active == true' >/dev/null; then
  exit 0
fi
OPERATION=check
[ "$EVENT" != start ] || OPERATION=start
if ! FACTS=$(printf '%s' "$INPUT" | bash @@CORE_SH@@ --vault @@VAULT_SH@@ --legacy "$OPERATION"); then
  REASON='Second Brain checker failed. Repair the registry/runtime or dependencies and persist state before stopping.'
else
  [ "$EVENT" != start ] || exit 0
  printf '%s' "$FACTS" | jq -e '.context_dirty == true' >/dev/null || exit 0
  REASON='Second Brain: unpersisted project work. Run /close, update CONTEXT.md and the active plan, then record the persistence receipt. Do not invent knowledge.'
fi
if [ "$EVENT" = stop ]; then
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
else
  jq -n --arg reason "$REASON" '{systemMessage: $reason}'
fi
