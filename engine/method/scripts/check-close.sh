#!/bin/bash
# Method hook (Stop / PreCompact): verifies that the vault's CONTEXT.md was
# updated during the session in projects where the method is instantiated.
# Usage: check-close.sh stop | check-close.sh precompact
set -u
EVENT="${1:-stop}"
INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

# Only applies to projects where the method is instantiated
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

# Avoid loop: if Stop already blocked once, don't block again
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$EVENT" = "stop" ] && [ "$STOP_ACTIVE" = "true" ] && exit 0

# Locate the vault's CONTEXT.md from the repo's CLAUDE.local.md.
# Vault-name-agnostic: matches any path ending in <vault>/projects/<p>/CONTEXT.md.
CONTEXT=$(grep -oE '[~/][^ `)]*/projects/[^ `)]*CONTEXT\.md' "$CWD/CLAUDE.local.md" 2>/dev/null | head -1)
CONTEXT="${CONTEXT/#\~/$HOME}"
{ [ -n "$CONTEXT" ] && [ -f "$CONTEXT" ]; } || exit 0

# Was it updated during this session? CONTEXT mtime vs the transcript's
# birth time; if there is no transcript, a 30-minute window.
CTX_M=$(stat -f %m "$CONTEXT" 2>/dev/null || echo 0)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  SESSION_START=$(stat -f %B "$TRANSCRIPT" 2>/dev/null || echo 0)
else
  SESSION_START=$(( $(date +%s) - 1800 ))
fi
[ "$CTX_M" -ge "$SESSION_START" ] && exit 0

REL="~${CONTEXT#$HOME}"
if [ "$EVENT" = "stop" ]; then
  R=$(printf '@@MSG_CLOSE_STOP_BLOCK@@' "$REL")
  jq -n --arg r "$R" \
    '{decision: "block", reason: $r}'
else
  M=$(printf '@@MSG_CLOSE_PRECOMPACT_MSG@@' "$REL")
  C=$(printf '@@MSG_CLOSE_PRECOMPACT_CTX@@' "$REL")
  jq -n --arg m "$M" \
        --arg c "$C" \
    '{systemMessage: $m, hookSpecificOutput: {hookEventName: "PreCompact", additionalContext: $c}}'
fi
exit 0
