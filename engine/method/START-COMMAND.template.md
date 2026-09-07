<!-- method-version: 4.0 -->

# Start — shared workflow

1. Detect the physical Git root (`git rev-parse --show-toplevel`, `pwd -P`).
   Resolve with `bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ resolve <repo-root>`.
   Exit 1 means unknown: report and recommend the provider's new-project workflow;
   do not invent a slug. Exit 2 means malformed registry/error: repair before work.
   Claude may use the unambiguous legacy anchor per PROJECT-REGISTRY.md.
2. Read `projects/<slug>/hub.md`, `CONTEXT.md` and the in-progress plan it references.
   Use the hub's cached repo tree; refresh only if absent or state says it changed.
   Read only convention-index entries relevant to the next action.
3. If SessionStart did not run, initialize its baseline by passing JSON containing
   `cwd` and the runtime session ID to the core's `start` operation (stdin). Never
   reset an existing session baseline to hide unpersisted work.
4. If the hub (or Claude legacy anchor) declares `## Code graph (Graphify)` and
   the CLI exists, refresh `graphify update . --no-cluster` at session open.
   Apply GRAPHIFY.md for structural questions before broad file reading.
   If unavailable, report the fallback and use bounded source searches.
5. Report current state (3–5 lines), branch, pending Git changes, goal, blockers,
   next action, conventions needed and any planned worker roles/model configuration.
6. Stop before implementation until the necessary plan is approved. Existing
   authorization applies within scope. Before persistible work, run the core's
   `mark-dirty <repo-root>` operation, including for planning-only sessions.

Read-only sessions with no new knowledge need no artificial CONTEXT update.
