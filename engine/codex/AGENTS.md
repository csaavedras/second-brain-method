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
  `bash @@CORE_SH@@ --vault @@VAULT_SH@@ mark-dirty .`.
- Close every task/session before stopping or compacting; persist verified
  state and the active checklist, then record the receipt per the close workflow.
- Skills: `$sb-start`, `$sb-close`, `$sb-learn`, `$sb-new-project`, `$sb-kickoff`.
- Workers: `second-brain-implementer`, `second-brain-tester`; explorer is built in.
- Use workspace-write sandbox and on-request approvals; review rules/hooks.
  Grant only this vault as an additional writable directory for persistence.
- Preserve team AGENTS.md. Do not create personal AGENTS.override.md or
  project .codex files. Review `/hooks` trust prompts; never bypass trust.
