<!-- method-version: 4.0 -->

# Provider capabilities and installation paths

Shared capability is defined by the method. File formats, invocation syntax and
runtime enforcement are adapter details. Defaults below respect CLAUDE_HOME,
CODEX_HOME and CODEX_SKILLS_HOME where configured.

| Capability | Shared semantic contract | Claude Code | Codex |
|---|---|---|---|
| Instructions | Thin personal rules | `~/.claude/CLAUDE.md` managed block | `${CODEX_HOME:-$HOME/.codex}/AGENTS.md` managed block |
| Workflows | `*-COMMAND.template.md` | `~/.claude/commands/*.md`, `/start` etc. | `$HOME/.agents/skills/sb-*/SKILL.md`, `$sb-start` etc. |
| Workers | Parent → Task Brief → Worker → Report | `~/.claude/agents/{implementer,tester}.md` | `~/.codex/agents/second-brain-{implementer,tester}.toml` |
| Session baseline | One session/repo observation | SessionStart | SessionStart |
| Close | Shared checker and persistence receipt | Stop blocks once | Stop blocks once |
| Compaction | Persist before losing context | PreCompact warning | PreCompact blocks while dirty |
| Permissions | Scoped authorization | settings.json ask/deny merged; existing local settings preserved | Existing config preserved; sandbox + approvals + method rules |
| Sandbox | Bound filesystem/network access | Native runtime controls | Recommend workspace-write, on-request; add only the vault for writes |
| Safety rules | Mutation/external gate | Native permissions | `~/.codex/rules/second-brain.rules`; default.rules untouched |
| Lookup | `00-index/projects.json` | Registry first, legacy anchor fallback | Registry, no project override |
| Routing | Explorer/Implementer/Reasoner/Tester | Configurable model tiers | Inherited configurable model/effort |
| Graphify | Shared query-first CLI | Same hub opt-in; legacy declaration supported | Same hub opt-in |
| Vault | One persistent state | Same projects/CONTEXT/plans/notes | Same projects/CONTEXT/plans/notes |

## Runtime setup

Codex: review `/hooks` after install/reinstall; new or changed definitions require
trust by hash. The installer never changes trust or config.toml. In a CLI session,
use a baseline such as `codex --sandbox workspace-write --ask-for-approval on-request
--add-dir <vault>` (one command line). An app session needs equivalent permission
to write the chosen vault. Do not grant the entire home directory or use full
access to make persistence work. Team/admin policy can still be stricter.

Current Codex custom agents are standalone TOML with name, description and
developer_instructions. No config.toml mutation or concurrency override is
necessary. They inherit model/effort and runtime permissions. If you have disabled
agents, enable them deliberately in your own config. Explorer stays built in.

Rules gate commands outside the sandbox, not every command executed inside it.
Exact prefixes do not cover arbitrary wrappers, absolute executables, Git `-C` or
`-c` variants. Sandbox protects Git metadata; approvals and instructions cover
remaining workflows. Never treat a rules file as a complete shell firewall or
broadly allow test/build runners outside the sandbox. Static and native policy
checks test representative prefixes; review each actual escalation.

Claude global ask/deny entries are merged with existing permissions. Legacy local
settings remain intact; new-project merges only verified safe commands. Legacy
PreCompact warns, matching the provider's nonblocking event. Both adapters share
facts and Stop guard semantics; see CLOSE-ENFORCEMENT.md for limits.

## Verified reference contracts

Checked 2026-09-07; local policy tests use Codex CLI 0.153.4. These references are
runtime documentation, not new dependencies on specific model names:

- [Global/project instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Skills](https://learn.chatgpt.com/docs/build-skills) and
  [explicit invocation metadata](https://learn.chatgpt.com/es-419/docs/build-skills)
- [Custom subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Lifecycle hooks and trust](https://learn.chatgpt.com/docs/hooks)
- [Approvals and sandbox](https://learn.chatgpt.com/docs/agent-approvals-security)
- [Rules and execpolicy checks](https://learn.chatgpt.com/docs/agent-configuration/rules)

Older clients without these primitives must be updated before relying on close
or compaction enforcement. Installing files alone does not prove hooks ran: review
trust and run the isolated smoke scenarios in tests/test-install.sh.
