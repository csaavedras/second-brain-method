<!-- method-version: 4.0 -->
# Personal working method — Second Brain

- Shared vault: `@@VAULT@@`; semantics: `@@VAULT@@/method/README.md`.
- Resolve this repository through `00-index/projects.json` in the vault;
  read `hub.md`, `CONTEXT.md` and only the active plan. See `PROJECT-REGISTRY.md`.
- Plan before code: use native plan mode when available, show a checklist,
  wait for approval; existing explicit approval remains valid within scope.
  Save approved multi-session or >5-step plans under the project's `plans/`.
- Git mutations, destructive operations and external writes need authorization.
  Work on feature/fix branches. Do not auto-commit or auto-push.
- Never read/store secret values: only variable names and access locations.
- Graphify is shared and opt-in: structure → graph, why/state → vault,
  implementation → source. Apply `GRAPHIFY.md`; fall back if CLI unavailable.
- Read conventions on demand from the hub index; keep loaded context small.
- Delegate bounded independent work with `TASK-BRIEF.template.md`, following
  `MULTI-AGENT.md`. Parent owns decisions, plan, integration and CONTEXT.md;
  workers receive only their brief and return evidence. Model/effort routing
  follows semantic roles in `MODEL-ROUTING.md`, with no fixed model dependency.
- Before persistible work (including planning with no code edits), run
  `bash @@CORE_SH@@ --vault @@VAULT_SH@@ --legacy mark-dirty .`.
- Close every task/session before stopping or compacting; persist verified
  state and the active checklist, then record the receipt per the close workflow.
- Commands: `/start`, `/close`, `/learn`, `/new-project`, `/kickoff`.
- Legacy `CLAUDE.local.md` and personal permissions remain supported.
- Worker roles: `implementer`, `tester`; read-only sweeps: native Explore.
