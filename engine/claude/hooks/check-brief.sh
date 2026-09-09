#!/bin/bash
# Method hook (SubagentStop): verifies that a subagent's final report shows
# verification evidence (a command run + its literal result) before letting
# the report through. Blocks the report if that evidence is missing.
# Usage: check-brief.sh
set -u
INPUT=$(cat)

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

# Only applies to projects where the method is instantiated
[ -f "$CWD/CLAUDE.local.md" ] || exit 0

# Avoid loop: if this hook already blocked once, don't block again
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

# Locate the subagent's transcript: prefer agent_transcript_path (the
# subagent's own transcript); fall back to transcript_path if absent.
AGENT_TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
FILE=""
if [ -n "$AGENT_TRANSCRIPT" ] && [ -f "$AGENT_TRANSCRIPT" ]; then
  FILE="$AGENT_TRANSCRIPT"
elif [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  FILE="$TRANSCRIPT"
fi
[ -n "$FILE" ] || exit 0

# Extract the LAST assistant message's text from the JSONL transcript.
# Tolerates .message.content being either an array of content blocks
# (take the text ones) or a plain string. Any parse issue yields empty.
REPORT=$(jq -rs '
  ([ .[] | select(.message.role? == "assistant") ] | last) as $m
  | if $m == null then empty
    else
      ($m.message.content) as $c
      | if ($c | type) == "array" then
          ([ $c[] | select(.type=="text") | .text ] | join("\n"))
        elif ($c | type) == "string" then
          $c
        else
          empty
        end
    end
' "$FILE" 2>/dev/null)

# No usable report text (missing/empty/unparseable transcript) → tolerate.
[ -n "$REPORT" ] || exit 0

# --- Verification heuristic (single source of truth) ---------------------
# A report "shows verification evidence" when it mentions verification
# (case-insensitive "verificat", covers Verification/verificación) AND
# shows some concrete evidence marker: a backtick (inline command), a
# shell-prompt "$ ", or a pass/exit signal (passed/green/ok/exit).
printf '%s' "$REPORT" | grep -qi 'verificat' &&
printf '%s' "$REPORT" | grep -qiE '`|\$ |passed|green|ok|exit' && exit 0
# ---------------------------------------------------------------------------

jq -n --arg r "Method brief rule: the subagent report must include a Verification section with the command run and its literal result, plus criteria evidence (one line per acceptance criterion). Run the brief's acceptance-criteria commands and re-emit the full report." \
  '{decision: "block", reason: $r}'
exit 0
