"""Shared close facts and explicit persistence receipts stored in the vault."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
from brain_runtime import (fingerprint, locked, project_context, repo_root,
                           stamp, write_json)


def read(path):
    value = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(value, dict):
        raise ValueError("Invalid runtime record; expected a JSON object")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vault", required=True)
    parser.add_argument("--legacy", action="store_true")
    parser.add_argument("operation", choices=["start", "check", "persist", "mark-dirty"])
    parser.add_argument("repo", nargs="?")
    args = parser.parse_args()
    payload = json.load(sys.stdin) if args.operation in ("start", "check") else {}
    if not isinstance(payload, dict):
        raise ValueError("Expected a hook JSON object")
    cwd = args.repo or payload.get("cwd") or str(Path.cwd())
    try:
        root = repo_root(cwd)
    except ValueError:
        print(json.dumps({"project_registered": False, "context_dirty": False}))
        return
    context = project_context(Path(args.vault).expanduser().resolve(), root, args.legacy)
    if context is None:
        print(json.dumps({"project_registered": False, "context_dirty": False}))
        return
    # Legacy anchors may point to a different vault; keep the state with that vault.
    vault = context.parents[2]
    runtime = vault / ".second-brain/runtime"
    key = hashlib.sha256(str(root).encode()).hexdigest()
    session = hashlib.sha256(str(payload.get("session_id") or "unknown").encode()).hexdigest()
    record = runtime / (key + ".json")
    baseline = runtime / (key + "-" + session + ".json")
    with locked(runtime / (key + ".lock")):
        state = read(record)
        start = read(baseline)
        signature, git_dirty = fingerprint(root)
        context_stamp = stamp(context)
        if args.operation == "mark-dirty":
            state["generation"] = time.time_ns()
            state["dirty_context"] = context_stamp
            write_json(record, state)
        elif args.operation == "persist":
            if context_stamp is None:
                raise ValueError("Write CONTEXT.md before marking persistence")
            previous_context = state.get("dirty_context", state.get("context", state.get("observed_context")))
            if not state:
                raise ValueError("Mark work dirty before updating CONTEXT.md and recording persistence")
            if context_stamp == previous_context:
                raise ValueError("CONTEXT.md must be updated before a new persistence receipt")
            state.update(signature=signature, context=context_stamp,
                         persisted_generation=state.get("generation"), persisted_at=time.time_ns())
            state.pop("dirty_context", None)
            write_json(record, state)
        elif args.operation == "start":
            # Resume/compaction must not overwrite an existing session baseline.
            if not start:
                write_json(baseline, {"signature": signature, "context": context_stamp,
                                     "started_at": time.time_ns()})
            if "observed_context" not in state:
                state["observed_context"] = context_stamp
                write_json(record, state)
        else:
            persisted = (context_stamp is not None and state.get("signature") == signature
                         and state.get("context") == context_stamp
                         and state.get("persisted_generation") == state.get("generation"))
            changed = signature != start["signature"] if start else git_dirty
            dirty = (changed or state.get("generation") != state.get("persisted_generation")
                     or context_stamp is None) and not persisted
            if "observed_context" not in state:
                state["observed_context"] = context_stamp
                write_json(record, state)
            print(json.dumps({"project_registered": True, "context_dirty": dirty,
                              "close_completed": persisted, "context": str(context)}))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, TypeError) as error:
        print(f"close checker: {error}", file=sys.stderr)
        sys.exit(2)
