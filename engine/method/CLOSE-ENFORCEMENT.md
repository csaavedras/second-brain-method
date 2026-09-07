<!-- method-version: 4.0 -->

# Close detection and limits

SessionStart supplies the runtime session ID and cwd to the shared core. The first
start for that session/repo records a baseline; resume/compaction cannot reset it.
Stop/PreCompact compare HEAD, Git status and tracked/untracked file metadata
(mtime, ctime, size and mode), without opening file contents or provider transcripts.
This catches edits, staged/unstaged work, untracked files and commits after start.
With no baseline, dirty Git state conservatively requires close.

Before planning or work, call `mark-dirty <repo-root>` with `--vault <vault>`.
This catches persistible conversation-only work that filesystem observation
cannot infer. It also records the pre-work CONTEXT metadata. After saving context
and reviewing the active checklist, call `persist <repo-root>`: it requires an
existing updated CONTEXT and records the current repo signature plus dirty marker.
The receipt lives in the same vault as CONTEXT and is shared by both providers.
A subsequent edit or dirty marker invalidates it. No timestamps in transcripts
or loose 30-minute freshness window are used.

Receipts establish that persistence was explicitly completed for the observed
state; they cannot judge whether prose accurately describes the work, verify the
meaning of checklist edits, or detect discussions when the agent omits mark-dirty.
Ignored files are outside Git observation. This is an accident-prevention harness,
not protection against a malicious agent with vault write access. Parent review
and scoped permissions remain necessary. Parallel sessions on one project should
coordinate context ownership; a receipt is not a substitute for merging notes.

Runtime files under `.second-brain/runtime/` are ignored and may be removed when
all sessions are closed; the notes and registry remain authoritative. Unknown
repos stay silent. Corrupt registry/runtime reports an error instead of silently
allowing dirty work. Stop respects the runtime's active guard to prevent loops.
Codex PreCompact returns continue=false while dirty; Claude only warns.
