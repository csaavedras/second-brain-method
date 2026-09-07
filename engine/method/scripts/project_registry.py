"""Idempotent repo-to-vault registry CLI."""
import argparse
import json
from pathlib import Path
import sys
from brain_runtime import locked, read_registry, repo_root, validate_registry, write_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", required=True)
    parser.add_argument("operation", choices=["init", "register", "resolve", "list", "add-root"])
    parser.add_argument("args", nargs="*")
    options = parser.parse_args()
    expected = {"init": (0,), "list": (0,), "resolve": (0, 1), "register": (2,), "add-root": (2,)}
    if len(options.args) not in expected[options.operation]:
        parser.error("register/add-root need <slug> <repo-root>; resolve takes [repo-root]")
    vault = Path(options.vault).expanduser().resolve()
    path = vault / "00-index/projects.json"
    with locked(path.with_suffix(".lock")):
        data = read_registry(vault)
        if options.operation == "init":
            if not path.exists():
                write_json(path, data)
        elif options.operation == "list":
            print(json.dumps(data, indent=2))
        elif options.operation == "resolve":
            root = str(repo_root(options.args[0] if options.args else Path.cwd()))
            match = next((p for p in data["projects"] if root in p["repo_roots"]), None)
            if not match:
                return 1
            print(match["slug"])
        else:
            slug, raw_root = options.args
            root = str(repo_root(raw_root))
            project = next((p for p in data["projects"] if p["slug"] == slug), None)
            owner = next((p for p in data["projects"] if root in p["repo_roots"]), None)
            if owner and owner["slug"] != slug:
                raise ValueError("Repo root already belongs to another project")
            if project is None:
                if options.operation == "add-root":
                    raise ValueError("Unknown project; register it first")
                project = {"slug": slug, "repo_roots": []}
                data["projects"].append(project)
            if root not in project["repo_roots"]:
                project["repo_roots"].append(root)
                validate_registry(data)
                write_json(path, data)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as error:
        print(f"project registry: {error}", file=sys.stderr)
        sys.exit(2)
