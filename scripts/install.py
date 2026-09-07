"""Non-destructive, preflighted installation of the shared method and adapters."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import uuid

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE / "engine/method/scripts"))
from brain_runtime import atomic_write, read_registry

BEGIN = "<!-- BEGIN SECOND BRAIN METHOD -->"
END = "<!-- END SECOND BRAIN METHOD -->"


def managed_block(existing, content):
    block = BEGIN + "\n" + content.rstrip() + "\n" + END
    if existing.count(BEGIN) != existing.count(END) or existing.count(BEGIN) > 1:
        raise ValueError("Corrupt Second Brain managed block; repair it before reinstalling")
    if BEGIN in existing:
        start, end = existing.index(BEGIN), existing.index(END)
        if end < start:
            raise ValueError("Reversed Second Brain managed block markers")
        return existing[:start] + block + existing[end + len(END):]
    return existing + ("\n\n" if existing and not existing.endswith("\n\n") else "") + block + "\n"


def check_destination(path):
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise ValueError(f"Refusing symlink destination: {parent}")
    if path.exists() and not path.is_file():
        raise ValueError(f"Expected a file: {path}")


def json_object(path):
    if not path.exists():
        return {}
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def merge_hooks(existing, distributed, owned):
    result = dict(existing)
    events = result.setdefault("hooks", {})
    if not isinstance(events, dict):
        raise ValueError("hooks must be an object")
    for event, additions in distributed["hooks"].items():
        groups = events.get(event, [])
        if not isinstance(groups, list):
            raise ValueError(f"Invalid hook groups for {event}")
        kept = []
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                raise ValueError(f"Invalid hook group for {event}")
            handlers = []
            for handler in group["hooks"]:
                if not isinstance(handler, dict):
                    raise ValueError("Invalid hook handler")
                if handler.get("command") not in owned:
                    handlers.append(handler)
            if handlers or not group["hooks"]:
                kept.append({**group, "hooks": handlers})
        events[event] = kept + additions
    return result


def main():
    if sys.version_info < (3, 9):
        raise ValueError("Python 3.9 or newer is required")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vault", nargs="?", default=str(Path.home() / "second-brain"))
    parser.add_argument("--platform", choices=["claude", "codex", "both"], default="claude")
    parser.add_argument("--force", action="store_true", help="Compatibility flag; never deletes knowledge")
    args = parser.parse_args()
    vault = Path(args.vault).expanduser().absolute()
    claude = Path(os.environ.get("CLAUDE_HOME", str(Path.home() / ".claude"))).expanduser().absolute()
    codex = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))).expanduser().absolute()
    skills = Path(os.environ.get("CODEX_SKILLS_HOME", str(Path.home() / ".agents/skills"))).expanduser().absolute()
    providers = ["claude", "codex"] if args.platform == "both" else [args.platform]
    roots = [vault] + ([claude] if "claude" in providers else []) + ([codex, skills] if "codex" in providers else [])
    for root in roots:
        if any(ord(c) < 32 for c in str(root)):
            raise ValueError("Installation paths cannot contain control characters")
        if root.is_symlink():
            raise ValueError(f"Refusing symlink installation root: {root}")
    vault, claude, codex, skills = [p.resolve() for p in (vault, claude, codex, skills)]
    roots = [vault] + ([claude] if "claude" in providers else []) + ([codex, skills] if "codex" in providers else [])
    for i, root in enumerate(roots):
        if root == Path.home().resolve() or root == SOURCE or SOURCE in root.parents or root in SOURCE.parents:
            raise ValueError("Install into a personal directory outside this source repository")
        for other in roots[i + 1:]:
            if root == other or root in other.parents or other in root.parents:
                raise ValueError("Vault and provider installation directories must not overlap")
    read_registry(vault)
    substitutions = {
        "@@VAULT@@": str(vault), "@@VAULT_SH@@": shlex.quote(str(vault)),
        "@@VAULT_TOML@@": json.dumps(str(vault), ensure_ascii=False)[1:-1],
        "@@CORE_SH@@": shlex.quote(str(vault / "method/scripts/check-close-core.sh")),
        "@@REGISTRY_SH@@": shlex.quote(str(vault / "method/scripts/project-registry.sh")),
    }

    def render(text):
        return re.sub(r"@@[A-Z_]+@@", lambda m: substitutions[m[0]], text)

    pending = {}

    def put(path, text, mode=0o600):
        check_destination(path)
        pending[path] = (text.encode(), mode)

    def copy_tree(source, destination):
        for file in sorted(source.rglob("*")):
            if file.is_file() and "__pycache__" not in file.parts and file.suffix != ".pyc":
                put(destination / file.relative_to(source), render(file.read_text()),
                    0o700 if file.suffix == ".sh" else 0o600)

    copy_tree(SOURCE / "engine/method", vault / "method")
    for provider in providers:
        target = claude if provider == "claude" else codex
        adapter = SOURCE / "engine" / provider
        global_name = "CLAUDE.md" if provider == "claude" else "AGENTS.md"
        global_path = target / global_name
        check_destination(global_path)
        put(global_path, managed_block(global_path.read_text() if global_path.exists() else "",
                                       render((adapter / global_name).read_text())))
        config_name = "settings.json" if provider == "claude" else "hooks.json"
        config_path = target / config_name
        check_destination(config_path)
        manifest_path = target / ".second-brain-install.json"
        check_destination(manifest_path)
        previous = json_object(manifest_path)
        hook_commands = []
        dist = json.loads((adapter / config_name).read_text())
        for groups in dist["hooks"].values():
            for group in groups:
                for handler in group["hooks"]:
                    command = handler["command"].replace("@@HOOK_SH@@", shlex.quote(str(target / "hooks/second-brain-check-close.sh")))
                    handler["command"] = command
                    hook_commands.append(command)
        owned = set(previous.get("hook_commands", [])) | set(hook_commands)
        if provider == "claude":
            owned.update(f"~/.claude/hooks/check-close.sh {e}" for e in ("stop", "precompact"))
        merged = merge_hooks(json_object(config_path), dist, owned)
        if provider == "claude":
            permissions = merged.setdefault("permissions", {})
            if not isinstance(permissions, dict):
                raise ValueError("Claude permissions must be an object")
            for key, values in dist.get("permissions", {}).items():
                current = permissions.setdefault(key, [])
                if not isinstance(current, list):
                    raise ValueError("Claude permission entries must be arrays")
                permissions[key] = current + [v for v in values if v not in current]
            copy_tree(adapter / "commands", target / "commands")
            copy_tree(adapter / "agents", target / "agents")
        else:
            for agent in (adapter / "agents").glob("*.toml"):
                put(target / "agents" / ("second-brain-" + agent.name), render(agent.read_text()))
            copy_tree(adapter / "skills", skills)
            copy_tree(adapter / "rules", target / "rules")
        put(target / "hooks/second-brain-check-close.sh", render((adapter / "hooks/check-close.sh").read_text()), 0o700)
        put(config_path, json.dumps(merged, indent=2) + "\n")
        put(manifest_path, json.dumps({"version": "4.0", "vault": str(vault), "hook_commands": hook_commands}, indent=2) + "\n")

    if not (vault / "00-index/projects.json").exists():
        put(vault / "00-index/projects.json", '{"version": 1, "projects": []}\n')
    if not (vault / "00-index/home.md").exists():
        put(vault / "00-index/home.md", "---\ntype: moc\ndate: " + datetime.now().date().isoformat() + "\ntags: [meta]\n---\n# Home — Second Brain\n\nMethod: `method/BRAIN.md`.\n\n## Active projects\n\nRegister with `/new-project` or `$sb-new-project`.\n\n## Study topics\n\n## Patterns\n")
    ignore = vault / ".gitignore"
    check_destination(ignore)
    original_ignore = ignore.read_text() if ignore.exists() else ""
    additions = [line for line in [".DS_Store", ".trash/", ".obsidian/workspace*", ".obsidian/cache", ".second-brain/", "00-index/projects.lock", "**/__pycache__/"] if line not in original_ignore.splitlines()]
    put(ignore, original_ignore + ("\n" if original_ignore and not original_ignore.endswith("\n") else "") + "".join(line + "\n" for line in additions))
    backup_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    changed = {p: value for p, value in pending.items() if not p.exists() or p.read_bytes() != value[0]}
    backups = {}
    for path in changed:
        if path.exists() and vault / "method" not in path.parents:
            root = next(root for root in roots if root in path.parents)
            backup = root / ".second-brain/backups" / backup_id / path.relative_to(root)
            check_destination(backup)
            backups[path] = backup
    for folder in ["projects", "patterns", "briefs", "learning/til", "learning/concept"]:
        check_destination(vault / folder / ".second-brain-preflight")
    method_changed = any(vault / "method" in p.parents for p in changed)
    if method_changed and (vault / "method").exists():
        destination = vault / ".second-brain/backups" / backup_id / "method"
        check_destination(destination / ".check")
        shutil.copytree(vault / "method", destination, symlinks=True, ignore=shutil.ignore_patterns("__pycache__"))
        print(f"Method snapshot backup: {destination}")
    for path, (data, mode) in changed.items():
        if path in backups:
            backup = backups[path]
            atomic_write(backup, path.read_bytes(), path.stat().st_mode & 0o777)
            print(f"Backed up {path} → {backup}")
        atomic_write(path, data, path.stat().st_mode & 0o777 if path.exists() and path.suffix != ".sh" else mode)
    for folder in ["projects", "patterns", "briefs", "learning/til", "learning/concept"]:
        (vault / folder).mkdir(parents=True, exist_ok=True)
    if not (vault / ".git").exists():
        subprocess.run(["git", "-C", str(vault), "init", "-q"], check=True)
    print(f"Second Brain Method 4.0 installed; providers: {', '.join(providers)}")
    print(f"Vault: {vault}\nMethod: {vault / 'method'}\nRegistry: {vault / '00-index/projects.json'}")
    for provider in providers:
        target = claude if provider == "claude" else codex
        print(f"{provider}: global instructions, agents and hooks → {target}")
        if not shutil.which(provider):
            print(f"Warning: {provider} CLI unavailable; static installation completed.")
    if "claude" in providers:
        print("Claude commands installed. Next: claude → /new-project → /start → /close")
    if "codex" in providers:
        print(f"Codex skills: {skills}\nRules: {codex / 'rules/second-brain.rules'}")
        print("Next: codex → /hooks (review/trust installed hooks) → $sb-new-project → $sb-start → $sb-close")
        print("Use workspace-write + on-request approvals; grant only the chosen vault as an additional writable directory. config.toml is preserved.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f"Install failed: {error}", file=sys.stderr)
        sys.exit(1)
