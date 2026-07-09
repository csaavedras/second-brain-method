# 🧠 Second Brain for Claude Code

> A working method that gives [Claude Code](https://claude.com/claude-code)
> persistent memory. Install once and every session **resumes where you left
> off**, without re-explaining anything. macOS.

---

## What it is

Claude Code remembers nothing between sessions: every time you open the
terminal, it starts blank. This method gives it a **memory** — a "second
brain" on your disk where the state of each project and everything you learn
is written down.

In practice, three things get installed together:

- A set of **commands** (`/start`, `/close`, `/learn`, …) that load and save
  your context with discipline.
- A **vault** (a folder) where all that knowledge lives, which you can open
  and browse in [Obsidian](https://obsidian.md).
- A set of **safety rules** so Claude never touches git, deletes files or
  exposes secrets without your permission.

---

## ✨ Why use it — the benefits

| Without the method | With the method |
|---|---|
| Every session starts from zero: you re-explain the project and Claude re-explores the repo, burning time and tokens | `/start` resumes in 30 seconds with the exact state and the next step |
| What you decided yesterday evaporates when you close the terminal | `/close` writes down what was done, what's left and **why** each thing was decided |
| What you study gets lost or scattered across loose notes | `/learn` accumulates your learning into a graph of connected notes that grows over time |
| Claude can make risky changes (git, deletes, branches) on its own | No git or deletes without your explicit approval; secrets are never read or stored |
| You waste tokens loading excess context on every message | Only the minimum needed is loaded and the rest is fetched on demand → **cheaper and faster** |

**In one sentence:** you work with an assistant that has memory, judgment and
brakes — and that tomorrow knows exactly where you left it.

The acid test: tomorrow you type `/start` and keep working **without
explaining anything**.

---

## Requirements

- **macOS** (this installer is Mac only).
- **[Claude Code](https://claude.com/claude-code)** installed (the `claude` CLI).
- **git** and **jq** — if you don't have jq: `brew install jq`.
- **[Obsidian](https://obsidian.md)** (optional, recommended) to view and
  browse your brain visually.

---

## Install

```bash
git clone https://github.com/csaavedras/second-brain-method.git
cd second-brain-method
./install.sh
```

That installs the method's commands and creates your vault at `~/second-brain`.
Want it somewhere else? `./install.sh ~/the/path/you/want`.

The installer **respects your existing configuration**: it backs up what you
had and only *adds* the method's hooks to your `settings.json`, without
clobbering your model, theme or plugins. When it finishes it prints the first
steps.

---

## How to work

Everything revolves around three memory operations: **load** (`/start`),
**save** (`/close`) and **capitalize** (`/learn`).

### Start a project
```bash
cd ~/my-project && claude
```
```
/new-project my-project    ← registers the project in your brain
/start                     ← opens the session
```

### A normal workday
```
/start          ← tells you where you left off and what the next step is
...you work...   ← Claude proposes a plan, you approve it, it executes
/close          ← at the end of each task and when you stop: saves the state
```
If you forget to close, the method reminds you before you finish.

### Learn something (with or without a project)
```
/learn          ← at the end of a chat: saves what was learned to your brain
```
Or specific: `/learn react hooks`.

### Review what you know
No Claude needed: open your vault in **Obsidian** and browse your projects'
state, the decisions you made and everything you've learned — graph view
included.

---

## The commands

| Command | When | What it does |
|---|---|---|
| `/new-project <name>` | When adding a project | Registers it in the brain and anchors the repo |
| `/start` | On opening each session | Loads the state and tells you the next step |
| `/close` | On closing each task and the session | Saves what was done, what's left and why |
| `/learn [topic]` | When you learn something that outlasts the day | Adds it to your knowledge graph |

---

## Where everything lives

- The commands and rules: in `~/.claude/` (Claude Code config).
- Your knowledge: in the **vault** (`~/second-brain` by default) — it's yours,
  local, and you can version it in your own git repo whenever you want.

To uninstall, restore the backup the installer left in `~/.claude/backups/`
and delete the vault folder if you no longer want it.

---

## Privacy

Your brain is **local**. If you decide to sync it with a git repo, keep in
mind the method is designed to **never** store secret values (tokens,
passwords): it only records *names* of variables and where to get them. Even
so, review before making any vault public.

---

## How does it work under the hood?

For anyone who wants the detail, the full method specification (the
architecture, the multi-agent system, the templates) lives inside your vault
at `method/README.md` once installed.

---

## License

MIT — use it, adapt it and share it.
