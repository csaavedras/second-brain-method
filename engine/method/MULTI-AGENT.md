<!-- method-version: 4.0 -->

# Parent → Task Brief → Worker → Report

The parent owns historical context, the approved plan, architecture decisions,
verification, integration and persistence. Workers receive only a bounded
TASK-BRIEF.template.md: goal, minimal context, relevant files, convention pointers,
allowed scope, verification commands and report format. Never send the whole vault.

The parent handles small 1–2-step edits inline. Delegate independent substantial
work when authorized by the user's task or applicable runtime instructions. Use
MODEL-ROUTING.md to select sufficient capability at the lowest practical cost.

Workers detect the stack from relevant manifests, follow neighboring conventions,
work only within the brief, and return doubts instead of making unapproved design
choices. They do not mutate Git or read secrets. They do not own CONTEXT.md or edit
persistent state unless that exact file is explicitly delegated by the parent.

Reports are at most ~30 lines: detected stack, files touched (one line each),
verification command and literal result, findings, doubts/blockers. The parent
checks evidence before marking work complete, rerunning relevant checks when
integration or uncertain reports justify it. Failed evidence stays unverified;
refine the brief and escalate capability where needed.

| Runtime | Explorer | Implementer | Tester |
|---|---|---|---|
| Claude Code | Native Explore | `agents/implementer.md` | `agents/tester.md` |
| Codex | Native explorer | `agents/second-brain-implementer.toml` | `agents/second-brain-tester.toml` |

Independent work can run in parallel with disjoint file scopes. Never knowingly
assign overlapping writes simultaneously. Reconcile reports sequentially and
validate integration. Multi-agent execution never bypasses plan approval or
sandbox/permissions. No worker silently expands scope or makes architecture
choices on behalf of the parent/human. Runtime defaults and live permission
settings still apply to children; prompts alone are not a security boundary.
