<!-- method-version: 4.0 -->

# New project — shared workflow

1. Detect Git root physically. If no repository exists, propose git init only
   with authorization. Resolve the registry first. An already registered root
   resumes that slug; never rename or duplicate its vault state.
2. Use the supplied kebab-case slug or derive it deterministically from the repo
   basename when unambiguous. Ask if ambiguous or colliding with an unrelated
   project. A worktree belongs to the existing project: add its root alias.
3. Read BRAIN.md and CONTEXT.template.md. Create missing directories only:
   `projects/<slug>/{plans,sessions,decisions}`. Create missing hub and CONTEXT with
   frontmatter FIRST, replacing template placeholders with observed facts.
   Hub: purpose, actual stack, local root, macro state, cached tree, convention
   docs index and real validation commands from manifests. CONTEXT: actual
   starting snapshot, live checklist and exact next action. Never overwrite
   existing notes; an existing project may simply need a new root registered.
4. Register with `bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ register <slug> <repo-root>`.
   Add one wikilink to `projects/<slug>/hub` in `00-index/home.md`, without duplicates.
5. Large repos only: offer optional Graphify; activate only if accepted, following
   GRAPHIFY.md. Small repos do not need it. Save opt-in in the shared hub.
6. Report new/preserved files, resolved slug and next command (start or kickoff).

Do not put Codex personal instructions, overrides or config inside the repo.
Claude adapter adds its compatibility anchor and local permissions separately;
existing anchors are preserved. No team file or global Git config is modified.
Registration is idempotent; validate before writing, stop on registry errors.
