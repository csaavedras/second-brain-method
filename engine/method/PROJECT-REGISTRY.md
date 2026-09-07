<!-- method-version: 4.0 -->

# Personal project registry

The common lookup source is `00-index/projects.json` in the vault:

```json
{"version": 1, "projects": [{"slug": "example", "repo_roots": ["/absolute/path/to/repo"]}]}
```

JSON version 1 contains unique kebab-case slugs and physical absolute roots. One
root cannot belong to two slugs. Extra metadata is preserved. Personal paths and
secrets never belong in the method's source repository. The registry is personal
vault data and is not a team instruction file.

```bash
bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ init
bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ register example /absolute/path/to/repo
bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ resolve .
bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ list
bash @@REGISTRY_SH@@ --vault @@VAULT_SH@@ add-root example /absolute/path/to/worktree
```

The helper uses Git's top-level path and physical path resolution (the equivalent
of `pwd -P`); callers in subdirectories or symlink aliases resolve the same repo.
Worktrees are explicit additional roots under the same slug. No inference from
similar basenames creates duplicate projects. Register is idempotent; add-root
requires a known slug. Updates take a file lock and use atomic replacement.
Resolve exits 0 with the slug, 1 for unknown, 2 for malformed data or invalid input.
Invalid JSON/schema fails without overwriting it. No automatic schema migration
is needed at v1; future migrations must back up first.

## Legacy Claude compatibility

Try registry first. If unknown, use the unique CONTEXT path from CLAUDE.local.md.
Backtick-quoted paths support spaces. If that path belongs to the configured vault,
its slug is valid and its context exists, `/start` can register it automatically
and preserve the anchor. If it points to a different vault, continue using that
legacy vault for Claude and report the mismatch; never silently relocate knowledge.
To share it with Codex, install both adapters against that existing vault and
register its roots. Ambiguous anchors require clarification. Never delete anchors.

Codex relies on the registry; it does not use personal AGENTS.override.md as an
anchor, because it can eclipse team AGENTS.md in the same directory. Team files
are preserved. Graphify opt-in and convention indexes belong in the shared hub;
when migrating a legacy anchor, copy those declarations into the hub once.
