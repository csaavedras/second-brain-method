<!-- method-version: 4.0 -->

# Close — shared workflow

Resolve the project via PROJECT-REGISTRY.md (Claude may fall back to its legacy
anchor). Use the owning vault project for cross-repo work. Never invent a project.

1. Inspect repository status and summarize the actual changes. Run only appropriate
   build/test/lint checks; record exact commands/results. Without passing evidence,
   keep a task `[~]` rather than `[x]`.
2. Save CONTEXT.md: ISO date, current state, changed tasks, decisions, findings and
   open questions. For partial work write the exact next-session resume point:
   files, pending decision, failing test and remaining command. Mark unconfirmed
   findings explicitly. Review/update the active plan's checklist as appropriate.
3. Record a durable non-obvious decision only when one was made, with rationale in
   `decisions/` and a hub link. Record cross-project recipes in `patterns/`, study
   in `learning/`, checking duplicates and BRAIN.md thresholds. Do not generate
   filler notes to satisfy a checklist.
4. At a milestone or CONTEXT >~150 lines, move closed history into
   `sessions/YYYY-MM-DD.md` and link it from CONTEXT. Keep current state small.
   Update the hub at milestones and its cached tree if structure changed.
5. After all persistence writes and any authorized code commits complete, record
   the detectable receipt (defer it until after steps 6–7 if those mutate code Git):
   `bash @@CORE_SH@@ --vault @@VAULT_SH@@ persist <repo-root>`.
   Claude anchor-only projects use `--legacy` before `persist`. This operation
   never writes knowledge; it records the current repo/context metadata. Do not
   call it to silence a hook without first saving actual state and checklist.
6. Propose an English Conventional Commit (scope when useful, ≤100 characters).
   Do not commit/push unless already explicitly authorized for this operation.
7. Check vault Git status. If changed, summarize and, with authorization, commit
   `chore(brain): YYYY-MM-DD close <project|study>`; push only if a remote exists
   and permission covers it. A backup failure is reported but does not undo close.
   Keep runtime metadata and secrets out of vault commits.

Do not move to the next task before verification and persistence. Work after a
receipt requires another close. Both providers consume the exact same CONTEXT.
