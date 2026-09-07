"""Shared filesystem mechanics; no provider response protocols or model calls."""
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def atomic_write(path, data, mode=0o600):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f"Refusing symlink: {path}")
    fd, temporary = tempfile.mkstemp(prefix=".second-brain-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data.encode() if isinstance(data, str) else data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def write_json(path, data):
    atomic_write(path, json.dumps(data, indent=2, ensure_ascii=False) + "\n")


@contextlib.contextmanager
def locked(path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise ValueError(f"Refusing lock symlink: {path}")
    with path.open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def git(root, *args, optional=False):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True)
    if result.returncode and not optional:
        raise ValueError("Git operation failed: " + " ".join(args))
    return result.stdout if result.returncode == 0 else b""


def repo_root(path):
    root = git(path, "rev-parse", "--show-toplevel").decode().strip()
    # Resolve symlinks physically, including callers in a subdirectory/worktree.
    return Path(root).resolve(strict=True)


def validate_registry(data):
    if not isinstance(data, dict) or type(data.get("version")) is not int or data.get("version") != 1 or not isinstance(data.get("projects"), list):
        raise ValueError("Unsupported project registry schema (expected version 1)")
    slugs, roots = set(), set()
    for entry in data["projects"]:
        if not isinstance(entry, dict):
            raise ValueError("Invalid project entry")
        slug, paths = entry.get("slug"), entry.get("repo_roots")
        if not isinstance(slug, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) or slug in slugs:
            raise ValueError("Invalid or duplicate project slug")
        if not isinstance(paths, list) or not paths:
            raise ValueError("Each project needs at least one repo root")
        slugs.add(slug)
        for root in paths:
            if not isinstance(root, str) or not Path(root).is_absolute() or root in roots or str(Path(root).resolve()) != root:
                raise ValueError("Invalid, noncanonical or duplicate repo root")
            roots.add(root)
    return data


def read_registry(vault):
    path = Path(vault) / "00-index/projects.json"
    if path.is_symlink():
        raise ValueError("Refusing registry symlink")
    if not path.exists():
        return {"version": 1, "projects": []}
    return validate_registry(json.loads(path.read_text()))


def resolve(vault, root):
    return next((p["slug"] for p in read_registry(vault)["projects"]
                 if str(root) in p["repo_roots"]), None)


def legacy_context(root):
    anchor = root / "CLAUDE.local.md"
    if not anchor.is_file():
        return None
    text = anchor.read_text()
    # Prefer the backtick-delimited template: supports spaces in vault paths.
    candidates = re.findall(r"`((?:/|~/)[^`\n]+/projects/[a-z0-9-]+/CONTEXT\.md)`", text)
    if not candidates:
        candidates = re.findall(r"(?:/|~/)[^\s`]+/projects/[a-z0-9-]+/CONTEXT\.md", text)
    paths = {Path(p).expanduser().resolve() for p in candidates}
    if len(paths) > 1:
        raise ValueError("Ambiguous legacy anchor; resolve it before continuing")
    return next(iter(paths), None)


def project_context(vault, root, legacy=False):
    slug = resolve(vault, root)
    if slug:
        return Path(vault) / "projects" / slug / "CONTEXT.md"
    return legacy_context(root) if legacy else None


def stamp(path):
    try:
        s = Path(path).lstat()
        return [s.st_mtime_ns, s.st_ctime_ns, s.st_size, s.st_mode]
    except FileNotFoundError:
        return None


def fingerprint(root):
    """Hash HEAD, index/worktree status and metadata, never read secret contents."""
    digest = hashlib.sha256()
    digest.update(git(root, "rev-parse", "HEAD", optional=True))
    status = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all")
    digest.update(status)
    names = git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    for name in sorted(set(names.split(b"\0")) - {b""}):
        digest.update(name)
        digest.update(repr(stamp(root / os.fsdecode(name))).encode())
    return digest.hexdigest(), bool(status)
