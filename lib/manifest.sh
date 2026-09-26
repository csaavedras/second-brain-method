# lib/manifest.sh — sha256 manifest of files the method has installed,
# tracked at <CLAUDE_HOME>/.second-brain/manifest.json as a flat JSON
# object: {"<absolute-path>": "<sha256>", ...}. Sourceable library:
# sourcing this file has no side effects, it only defines functions.
# bash 3.2 safe (no associative arrays, no ${var//pat/rep} on data-derived
# values). Requires jq.
#
# CLAUDE_HOME is read from the environment at call time (never cached at
# source time), defaulting to "$HOME/.claude" like the rest of the method.
#
# Concurrency note: manifest_set/manifest_remove do a full read-modify-
# write of the manifest file with no locking. That is intentional and
# sufficient for this CLI's use case (a single sequential install/apply
# run); do not call these concurrently from multiple processes without
# adding a lock of your own.
#
# Usage:
#   manifest_path                  -> prints the manifest file path for
#                                      the current CLAUDE_HOME
#   manifest_sha256 <file>         -> prints sha256 of <file>'s current
#                                      content; prints nothing and returns
#                                      non-zero if <file> is missing
#   manifest_get <path>            -> prints the recorded sha for <path>
#                                      (empty, exit 0, if absent or the
#                                      manifest file doesn't exist — never
#                                      errors)
#   manifest_set <path> <sha>      -> creates the manifest ({}) if missing,
#                                      sets/overwrites the <path> entry,
#                                      writes atomically (temp file + mv)
#   manifest_remove <path>         -> deletes the <path> entry if present;
#                                      no-op if absent or manifest missing

manifest_path() {
  local home="${CLAUDE_HOME:-$HOME/.claude}"
  printf '%s\n' "$home/.second-brain/manifest.json"
}

manifest_sha256() {
  local file="$1"
  if [ -z "${file:-}" ] || [ ! -f "$file" ]; then
    return 1
  fi
  shasum -a 256 "$file" | cut -d' ' -f1
}

manifest_get() {
  local path="$1" mpath
  mpath="$(manifest_path)"
  [ -f "$mpath" ] || return 0
  jq -r --arg p "$path" '.[$p] // empty' "$mpath" 2>/dev/null
}

manifest_set() {
  local path="$1" sha="$2" mpath dir tmp

  if [ -z "${path:-}" ] || [ -z "${sha:-}" ]; then
    echo "manifest_set: usage: manifest_set <path> <sha>" >&2
    return 1
  fi

  mpath="$(manifest_path)"
  dir="$(dirname "$mpath")"
  mkdir -p "$dir" || { echo "manifest_set: failed to create $dir" >&2; return 1; }
  [ -f "$mpath" ] || printf '{}' > "$mpath"

  tmp="$(mktemp "$dir/.manifest.XXXXXX")" || { echo "manifest_set: mktemp failed" >&2; return 1; }
  if ! jq --arg p "$path" --arg s "$sha" '.[$p] = $s' "$mpath" > "$tmp" 2>/dev/null; then
    echo "manifest_set: jq failed to update $mpath" >&2
    rm -f "$tmp"
    return 1
  fi
  if ! mv "$tmp" "$mpath"; then
    echo "manifest_set: failed to write $mpath" >&2
    rm -f "$tmp"
    return 1
  fi
  return 0
}

manifest_remove() {
  local path="$1" mpath dir tmp

  if [ -z "${path:-}" ]; then
    echo "manifest_remove: usage: manifest_remove <path>" >&2
    return 1
  fi

  mpath="$(manifest_path)"
  [ -f "$mpath" ] || return 0

  dir="$(dirname "$mpath")"
  tmp="$(mktemp "$dir/.manifest.XXXXXX")" || { echo "manifest_remove: mktemp failed" >&2; return 1; }
  if ! jq --arg p "$path" 'del(.[$p])' "$mpath" > "$tmp" 2>/dev/null; then
    echo "manifest_remove: jq failed to update $mpath" >&2
    rm -f "$tmp"
    return 1
  fi
  if ! mv "$tmp" "$mpath"; then
    echo "manifest_remove: failed to write $mpath" >&2
    rm -f "$tmp"
    return 1
  fi
  return 0
}
