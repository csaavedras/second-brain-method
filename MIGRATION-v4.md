<!-- method-version: 4.0 -->
# Migrating to v4.0

v4.0 adds multi-provider Claude Code + Codex support without changing the vault as
the source of truth. There is one method, one registry and one persistent state.

## Existing Claude users

```bash
./install.sh --platform claude
```

Pass your existing vault path if custom. Existing projects, plans, sessions,
decisions, patterns and learning remain intact. The installer updates known method
files without nesting `method/method`, backs up the old method snapshot and merges
global instructions/hooks/permissions. `--force` is accepted but never erases data.

Legacy `CLAUDE.local.md` and `.claude/settings.local.json` are preserved. Start tries
the registry first, then a unique legacy CONTEXT path. It can register a legacy
project when the configured vault matches. Copy legacy convention/Graphify indexes
to the hub for both providers. Unknown roots are not guessed; ambiguous paths need
clarification. A legacy anchor pointing to another vault continues to work in
Claude; install both against that vault to share it with Codex.

## Add Codex alongside Claude

```bash
./install.sh --platform both
```

Or use `--platform codex` alone. Skills go to `$HOME/.agents/skills/sb-*`; namespaced
agents and rules go under CODEX_HOME. The installer does not replace config.toml,
default.rules, unrelated skills, or team repository instructions. Python 3.9+ is
now required for safe atomic JSON/managed-block operations (no third-party packages).

Review `/hooks` in Codex after installation. Trust is tied to the handler definition
hash, so new/changed hooks may need approval. The installer never bypasses trust.
Keep workspace-write/on-request settings and explicitly grant the vault directory
for persistence. No personal AGENTS.override.md or project .codex files are needed.

## Register existing projects and worktrees

```bash
bash <vault>/method/scripts/project-registry.sh --vault <vault> init
bash <vault>/method/scripts/project-registry.sh --vault <vault> register example /path/to/repo
bash <vault>/method/scripts/project-registry.sh --vault <vault> add-root example /path/to/worktree
```

Replace placeholders and quote paths containing spaces. Registry init preserves
valid existing data; malformed or unsupported schemas fail safely. Register the
same slug for existing notes. It does not create or overwrite CONTEXT. New-project
creates missing notes only. Close in one provider, start in the other.

## Backups and rollback

Changed owned files are backed up under each installation root's
`.second-brain/backups/<UTC-timestamp>-<unique-id>/`, retaining relative paths.
The previous method snapshot is backed up under the vault at that same location.
Unchanged reinstalls create no new file copies. Legacy v3 backups under
`~/.claude/backups/` are untouched. Global instructions outside managed markers
remain intact, including previous hand-written/v3 rules; review obsolete rules
there if they conflict with your intended v4 workflow.

To roll back, close sessions, inspect the timestamped backup, then restore the
specific instructions/settings/hooks/agents/skills/rules and method snapshot you
intend to revert. Restore matching hook config and scripts together. Review Codex
hook trust again. Never delete the vault or its notes to uninstall an adapter.
Do not restore an older registry over newer project registrations.

The installer refuses symlink-managed targets and malformed managed blocks rather
than guessing what to overwrite. Repair those paths/configuration deliberately
and rerun. It does not install tools globally or change system configuration.
