# lib/config.sh — the method's install-time config file at
# <CLAUDE_HOME>/.second-brain/config.json:
#   {"version": "...", "lang": "...", "vault": "...", "repo": "...", "installed_at": "..."}
# Sourceable library: sourcing this file has no side effects, it only
# defines functions. bash 3.2 safe. Requires jq.
#
# CLAUDE_HOME is read from the environment at call time (never cached at
# source time), defaulting to "$HOME/.claude" like the rest of the method.
#
# Usage:
#   config_path                        -> prints the config file path for
#                                          the current CLAUDE_HOME
#   config_exists                      -> exit 0 if the config file exists,
#                                          1 otherwise
#   config_get <key>                   -> prints the value for <key>
#                                          (empty, exit 0, if missing or no
#                                          config file — never errors)
#   config_write <version> <lang> <vault> <repo> <installed_at>
#                                       -> writes the full config object
#                                          atomically via jq --arg (never
#                                          hand-built JSON strings — vault
#                                          paths may contain quotes)

config_path() {
  local home="${CLAUDE_HOME:-$HOME/.claude}"
  printf '%s\n' "$home/.second-brain/config.json"
}

config_exists() {
  local cpath
  cpath="$(config_path)"
  [ -f "$cpath" ]
}

config_get() {
  local key="$1" cpath
  cpath="$(config_path)"
  [ -f "$cpath" ] || return 0
  jq -r --arg k "$key" '.[$k] // empty' "$cpath" 2>/dev/null
}

config_write() {
  local version="$1" lang="$2" vault="$3" repo="$4" installed_at="$5"
  local cpath dir tmp

  cpath="$(config_path)"
  dir="$(dirname "$cpath")"
  mkdir -p "$dir" || { echo "config_write: failed to create $dir" >&2; return 1; }

  tmp="$(mktemp "$dir/.config.XXXXXX")" || { echo "config_write: mktemp failed" >&2; return 1; }
  if ! jq -n \
    --arg version "$version" \
    --arg lang "$lang" \
    --arg vault "$vault" \
    --arg repo "$repo" \
    --arg installed_at "$installed_at" \
    '{version: $version, lang: $lang, vault: $vault, repo: $repo, installed_at: $installed_at}' \
    > "$tmp" 2>/dev/null; then
    echo "config_write: jq failed to build config" >&2
    rm -f "$tmp"
    return 1
  fi
  if ! mv "$tmp" "$cpath"; then
    echo "config_write: failed to write $cpath" >&2
    rm -f "$tmp"
    return 1
  fi
  return 0
}
