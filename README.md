# 🧠 Second Brain for Claude Code

**English** · [Español](README.es.md)

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
- **git**.
- **jq** — `brew install jq`.
- **perl** — ships with macOS, nothing to install.
- **[Obsidian](https://obsidian.md)** (optional, recommended) to view and
  browse your brain visually.

---

## Install

```bash
git clone https://github.com/csaavedras/second-brain-method.git
cd second-brain-method
./sbm install
```

Without flags it asks `Language [en]:` and `Vault path [~/second-brain]:`,
Enter-through defaults included. To skip the prompts: `./sbm install --yes`,
or be explicit with `--lang en|es` and `--vault PATH` (accepts `~`). Already
installed? `sbm` says so and points you to `./sbm update` instead.

A brand-new or empty vault gets scaffolded (folders, `.gitignore`, a starter
`00-index/home.md`, its own `git init`); an existing vault keeps its content
— only the method's `method/` files are added (plus a `git init` if it isn't
a git repo yet). It finishes with a "HOW TO
START" checklist — see [How to work](#how-to-work).

`./install.sh` still works too, as a thin alias for `./sbm install` — prefer
`./sbm`. Every subcommand also honors a `CLAUDE_HOME` env var (default
`~/.claude`), handy to try the method in a sandbox first.

---

## Update

```bash
./sbm update
```

By default this pulls (`git pull --ff-only`) the repo you installed from
(must be on `main`, clean, else `sbm` suggests `--no-pull`), then re-applies
the method. Flags: `--no-pull` (apply as is), `--take-new` (see below),
`--lang en|es`.

**Nothing you edited is ever silently overwritten** — every managed file is
tracked by checksum. Untouched files update in place; an edited file (or a
pre-existing file of your own) gets its new version written next to it as
`<file>.new` to merge by hand; `--take-new` replaces it instead, backing the
old one up to `~/.claude/.second-brain/backups/<UTC timestamp>/…`.
`settings.json` is always merged (your model, theme, plugins and hooks
stay). `CLAUDE.md`: only the block between the `BEGIN`/`END SECOND BRAIN
METHOD` markers is managed; an old install with no markers gets a
`CLAUDE.md.new`; broken markers abort before touching anything.

Install and update both end with a summary —
`▸ added=N updated=N conflict=N taken=N deleted=N orphaned=N` —
where `conflict`/`taken` need your review (`.new` written / replaced with a
backup) and `deleted`/`orphaned` are files dropped from the method, removed
if unedited or left in place if you'd edited them.

---

## Status

```bash
./sbm status
```

Read-only: installed version, language and vault; warns if this repo's
version has moved on (`run ./sbm update`); lists any pending `.new` files
and any managed file edited since the last apply — or, when there's nothing
to look at, `ok — no .new files, nothing edited since the last apply.`

---

## Language

`en` (English) or `es` (rioplatense voseo Spanish) — set at install, switched
later with `./sbm update --lang <en|es>`. Translated: `CLAUDE.md`'s block,
the commands, the agents, the vault's `method/` docs, and `sbm`'s own
messages; command and file names never change. Language and vault path are
remembered in `~/.claude/.second-brain/config.json`.

---

## Adopting an existing setup

Already have a hand-rolled `~/.claude`, or an old version of this method?
`./sbm install --vault <your existing vault>` — nothing is overwritten.
Anything of yours that collides comes out as `<file>.new`; `./sbm status`
lists them all, then merge by hand or `./sbm update --no-pull --take-new`
to take the method's version everywhere (old files backed up first).

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
| `/kickoff [name] [brief]` | Kicking off a project from a master prompt | Registers the project, saves the brief, derives the brain and proposes a first plan |
| `/start` | On opening each session | Loads the state and tells you the next step |
| `/close` | On closing each task and the session | Saves what was done, what's left and why |
| `/learn [topic]` | When you learn something that outlasts the day | Adds it to your knowledge graph |
| `/gate` | Before leaving a commit message | Runs the review lenses that fit the diff and gives a READY/NOT-READY verdict |

---

## Where everything lives

- The commands and rules: in `~/.claude/` (Claude Code config), plus its own
  state under `~/.claude/.second-brain/` (`config.json`, `manifest.json`,
  `backups/`).
- Your knowledge: in the **vault** (`~/second-brain` by default) — it's
  yours, local, and you can version it in your own git repo.

---

## Uninstall

There's no `sbm uninstall` — removing the method is a manual, deliberate
step so it never takes your vault or your own `~/.claude` customizations
with it:

```bash
# every file the method installed (commands, agents, hooks, the vault's method/)
jq -r 'keys[]' ~/.claude/.second-brain/manifest.json |
  while IFS= read -r f; do rm -f "$f"; done
rm -rf ~/.claude/.second-brain/   # the method's own state
```

Then, by hand: delete the block between the `BEGIN`/`END SECOND BRAIN
METHOD` markers in `~/.claude/CLAUDE.md`, and remove the method's hook
entries from `~/.claude/settings.json`. The vault is yours — keep it or
delete it, independently of the above.

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
