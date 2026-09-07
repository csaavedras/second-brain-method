<!-- method-version: 4.0 -->
# Second Brain Method for agentic coding

Persistent context, Graphify, safe harnesses and multi-agent workflows for
**Claude Code and OpenAI Codex**. A personal file-based vault lets either runtime
resume verified work without depending on conversation history.

## Features

- One persistent vault: context, approved plans, decisions, sessions and learning.
- Claude + Codex adapters over one provider-agnostic method.
- Optional Graphify: shared query-first CLI, no mandatory MCP or model API key.
- Context hygiene: thin global rules, live context, on-demand conventions.
- Plan-before-code, scoped approvals and branch discipline.
- Parent → Task Brief → Worker → Report, with configurable capability-based routing.
- Close enforcement and protection before compaction, using shared filesystem facts.
- No secrets, no automatic push and no personal Codex files in team repositories.

## Install (macOS)

Requires Bash, git, jq and Python 3.9+ (standard library only). Install the selected
provider CLI before using it; its absence does not prevent static installation.
Obsidian is optional for browsing the vault.

```bash
git clone https://github.com/csaavedras/-second-brain-method.git
cd ./-second-brain-method
./install.sh --platform claude
./install.sh --platform codex
./install.sh --platform both
```

Choose one invocation. Default `./install.sh` still installs Claude, with the vault
at `~/second-brain`. Existing positional usage is preserved:

```bash
./install.sh ~/custom-vault --platform both
./install.sh --force --platform both
```

Existing knowledge is preserved even with `--force`. Instructions use managed
blocks; hooks and permissions merge; modified owned files receive timestamped
backups. Reinstalling does not duplicate blocks/hooks or nest method snapshots.
Malformed config, registry or managed blocks fail before configuration changes.
Configuration roots: CLAUDE_HOME, CODEX_HOME; skills default to `$HOME/.agents/skills`
(and can be redirected with CODEX_SKILLS_HOME). The summary shows installed paths.

Codex users: review `/hooks` to trust the installed handlers. Retain workspace-write
and on-request approvals; give the session write access only to the chosen vault
in addition to the project (`--add-dir <vault>` in CLI). Your config.toml is preserved.
Details: [provider matrix](engine/method/PROVIDERS.md).

## Daily workflow

| Step | Claude | Codex |
|---|---|---|
| Register repository | `/new-project` | `$sb-new-project` |
| Resume | `/start` | `$sb-start` |
| Brief → initial plan | `/kickoff` | `$sb-kickoff` |
| Persist task/session | `/close` | `$sb-close` |
| Capture reusable knowledge | `/learn` | `$sb-learn` |

Start loads the shared hub, CONTEXT and active plan. Approve the plan, work, verify,
then close before stopping. For work with no source changes, mark-dirty (part of
the workflow) makes persistence requirements visible to the harness. Read-only
sessions require no filler notes.

## Switching providers

```text
Claude /close → vault persisted → Codex $sb-start
Codex $sb-close → vault persisted → Claude /start
```

Both resolve the same physical repo through `00-index/projects.json` and own the
same `projects/<slug>/CONTEXT.md`. Worktrees use additional root aliases, not
separate vault projects. Cross-repo work has one owning live context.

Graphify is a **shared capability**. Its optional hub declaration is read by both
providers. Refresh at session open when configured and available, query structure
before broad source exploration, read the vault for why/state, inspect code for
implementation. Small repos and missing Graphify use normal bounded searches.

## Architecture and compatibility

```text
engine/
  method/   shared semantics, templates, registry and close checker
  claude/   commands, agents, global instructions, hooks and permissions
  codex/    skills, TOML agents, global instructions, hooks and rules
```

v4 preserves Claude v3.x vaults, legacy anchors and personal settings. Migration,
backups and rollback: [MIGRATION-v4.md](MIGRATION-v4.md). Full method:
[engine/method/README.md](engine/method/README.md), installed at `<vault>/method/`.

## Security and limitations

No secret values in notes, source control or configuration examples. Git mutations,
destructive actions and external publishing require scoped authorization. Existing
team instructions and user configuration are preserved. Codex uses the registry,
never an automatically installed personal AGENTS.override.md in a project.

Hooks need runtime support and trust. Codex PreCompact blocks; Claude PreCompact
warns. Rules apply outside the sandbox; they are one layer with sandbox and
approvals. Close receipts detect filesystem changes and explicit dirty markers,
but cannot judge the accuracy of prose or unmarked conversation-only work.
See [enforcement boundaries](engine/method/CLOSE-ENFORCEMENT.md).

## Validation

```bash
bash tests/test-install.sh
```

The suite uses disposable HOME directories and fake repositories. It requires no
provider login or model calls. Native Codex policy checks run when the CLI exists;
static rules validation also runs without it. CI runs on macOS.

## License

MIT.
