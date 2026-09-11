#!/bin/bash
# Method hook (SubagentStop): verifies that a subagent's final report shows
# verification evidence (a command run + its literal result) before letting
# the report through. Blocks the report if that evidence is missing.
# Scoped to subagents dispatched with a TASK BRIEF (first user message
# contains "# TASK BRIEF") — Explore/Plan/code-review subagents are never
# blocked by this hook.
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

# Locate the subagent's own transcript. Only agent_transcript_path is a
# subagent transcript; transcript_path (the parent's) is not a valid
# fallback here.
FILE=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

# Scope: only enforce on subagents dispatched with a TASK BRIEF. Extract the
# text of the FIRST message with role == "user" in the transcript (content
# may be a plain string or an array of blocks — take the text ones).
FIRST_USER=$(jq -rs '
  ([ .[] | select(.message.role? == "user") ] | first) as $m
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

printf '%s' "$FIRST_USER" | grep -q '# TASK BRIEF' || exit 0

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
# Passes only when BOTH hold:
#   a) some line matches: Verification: `<non-empty>` -> <non-empty>
#      (arrow may be "→" or "->")
#   b) the report contains a "Criteria evidence" section (case-insensitive)
VERIF_RE='Verification:[[:space:]]*`[^`]+`[[:space:]]*(→|->)[[:space:]]*[^[:space:]]'

printf '%s' "$REPORT" | grep -Eq "$VERIF_RE" &&
printf '%s' "$REPORT" | grep -qi 'criteria evidence' && exit 0
# ---------------------------------------------------------------------------

jq -n --arg r 'Method brief rule: the subagent report must include a Verification line for each acceptance-criteria command, in EXACTLY this shape: `Verification: `<command>` -> <literal result>` (arrow may be "->" or "→"), plus a "Criteria evidence" section with one line per acceptance criterion. Run the brief'"'"'s acceptance-criteria commands and re-emit the full report.' \
  '{decision: "block", reason: $r}'
exit 0
