<!-- method-version: 4.0 -->

# Second Brain Method — v4.0

The personal engineering method has one provider-agnostic core (`engine/method`)
and two thin adapters (`engine/claude`, `engine/codex`). The installed core lives
in the vault's `method/` and works without the original clone. v4.0 adds
multi-provider Claude Code + Codex support without changing the vault as the
source of truth. Runtime details and installation paths: [PROVIDERS.md](PROVIDERS.md).

## Persistent state and personal setup

The vault owns project `hub.md`, `CONTEXT.md`, plans, sessions, decisions, patterns,
learning and briefs. Conversations and provider memory are never the only copy.
Global instructions are a small personal layer; project lookup uses the personal
[registry](PROJECT-REGISTRY.md). Team repository instructions remain authoritative
for team conventions. Do not install personal Codex files in the team's repo.
Legacy Claude anchors remain compatible; the registry is common to both runtimes.

| Action | Claude | Codex |
|---|---|---|
| Start | `/start` | `$sb-start` |
| Close | `/close` | `$sb-close` |
| Learn | `/learn` | `$sb-learn` |
| Kickoff | `/kickoff` | `$sb-kickoff` |
| New project | `/new-project` | `$sb-new-project` |

## Session cycle

Register → start → plan → human approval → bounded work → verify → close.
Each `*-COMMAND.template.md` defines shared semantics; adapters only bind the
provider's command/skill name, lookup compatibility and protocol. Read the
relevant workflow when invoked; do not load every guide or the entire vault.

Before any persistible work, including design discussions with no code change,
run `scripts/check-close-core.sh --vault <vault> mark-dirty <repo>`.
Start reads hub, live context and only the active plan, then presents status and
next action. Close records evidence, updates context and checklist, and records a
persistence receipt. A session with an unfinished task saves its exact resume point.

## Plan-before-code and gates

Present a concrete checklist and receive approval before implementation. Use the
runtime's native plan/read-only mode when available. Persist approved plans for
multi-session or >5-step tasks under `projects/<slug>/plans/YYYY-MM-DD-task.md`.
CONTEXT references the plan rather than duplicating it. Existing explicit approval
remains valid within its scope; new architecture decisions go to the human.

Git mutation, destructive operations, writes outside the workspace and external
publication require authorization. Feature/fix work uses its own branch. Never
turn a one-time approval into a permanent permissive rule. No secrets: store only
variable names and where access is obtained. Do not read secret files to orient.

Instructions explain; sandbox, approvals, permissions, hooks and rules enforce
what each runtime supports. [PROVIDERS.md](PROVIDERS.md) documents the actual
boundaries, including rules' scope outside the sandbox and hook trust requirements.

## Context hygiene and Graphify

Keep global instructions thin (roughly 40 lines). Load CONTEXT and an active plan;
read convention docs only for the task, through the hub's one-line index. Cache the
repo tree in the hub and refresh only when missing or structurally stale. Read
large files in relevant sections. For bounded work, use [MULTI-AGENT.md](MULTI-AGENT.md)
and [TASK-BRIEF.template.md](TASK-BRIEF.template.md); verify every worker report.
Use the cheapest sufficiently capable model/effort per [MODEL-ROUTING.md](MODEL-ROUTING.md).

[Graphify](GRAPHIFY.md) is an optional shared CLI capability for large repos:
structure → graph; why/state → vault; implementation → source. No mandatory MCP
or API key. A missing CLI or a small repository never blocks normal exploration.

## Close enforcement

Shared facts: `scripts/check-close-core.sh`. Provider wrappers translate those
facts into lifecycle responses. SessionStart records a baseline; Stop checks
tracked/untracked metadata, HEAD and explicit dirty markers against persistence.
Stop blocks once and respects `stop_hook_active`. Codex PreCompact stops before
compaction while dirty; Claude PreCompact warns (its runtime does not support
blocking this event). Neither wrapper invents or writes knowledge.

The receipt is written only after CONTEXT and the active checklist have been
saved. Subsequent edits invalidate it. Runtime receipts/baselines are disposable
metadata in `.second-brain/runtime/` inside the vault, ignored by Git. They never
replace notes. Do not parse provider transcripts: their formats are unstable.
See [CLOSE-ENFORCEMENT.md](CLOSE-ENFORCEMENT.md) for detection boundaries.

## Maintaining state

A task is `[x]` only with appropriate passing verification recorded; use `[~]`
for partial/unverified work. Archive completed phases or context over ~150 lines
into project sessions, leaving only current state, next action, live checklist,
current decisions and open questions. Update hub macro state at milestones and
cached tree after structural changes. Record durable decisions and reusable
learning only when warranted; note formats and thresholds: [BRAIN.md](BRAIN.md).

Cross-repo tasks have exactly one owning CONTEXT in the primary vault project.
Secondary projects keep their own registry mappings and link to the owning task.
Never maintain two live states for the same task. Close with either runtime and
start with the other against the same registry and context.

Improve shared semantics here, provider primitives in adapters. Keep every
method-version marker at 4.0 for this release; never manually duplicate workflows.
