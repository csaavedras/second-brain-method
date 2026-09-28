# lib/settings-merge.sh — merge the method's own hooks into the user's
# ~/.claude/settings.json without touching the user's own config. Sourceable
# library: sourcing this file has no side effects, it only defines
# settings_merge_apply(). bash 3.2 safe (no associative arrays, no
# ${var//pat/rep} on data-derived values). Requires jq.
#
# This is install.sh step 4's jq merge, extracted verbatim into a function
# so both `sbm install` and `sbm update` (via lib/apply.sh) can call it.
#
# Usage:
#   settings_merge_apply <user_settings_path> <dist_settings_path>
#     - <user_settings_path> exists     -> jq -s merge: for every hook event
#       the method ships (<dist_settings_path>'s .hooks keys), drop any
#       previously-installed method entries from the user's config (matched
#       by script name: check-close|check-brief|metrics-event) and append
#       the dist's current entries for that event. Every other key/event in
#       the user's settings.json (their own hooks, unrelated top-level
#       keys) survives untouched. Written atomically (temp file + mv).
#     - <user_settings_path> missing    -> <dist_settings_path> is copied
#       to <user_settings_path> as-is (parent dir created if needed).
#     Idempotent either way: running it again with the same dist file is a
#     no-op in effect (the merge recomputes the same result).

settings_merge_apply() {
  local user_s="$1" dist_s="$2" tmp dir

  if [ -z "${user_s:-}" ] || [ -z "${dist_s:-}" ]; then
    echo "settings_merge_apply: usage: settings_merge_apply <user_settings_path> <dist_settings_path>" >&2
    return 1
  fi
  [ -f "$dist_s" ] || { echo "settings_merge_apply: dist settings not found: $dist_s" >&2; return 1; }

  dir="$(dirname "$user_s")"
  mkdir -p "$dir" || { echo "settings_merge_apply: failed to create $dir" >&2; return 1; }

  if [ -f "$user_s" ]; then
    tmp="$(mktemp "$dir/.settings.XXXXXX")" || { echo "settings_merge_apply: mktemp failed" >&2; return 1; }
    if ! jq -s '
      .[0] as $u | .[1] as $d
      | $u
      | .hooks = (.hooks // {})
      | .hooks = reduce ($d.hooks | keys[]) as $ev (.hooks;
          .[$ev] = (((.[$ev] // [])
                      | map(select(([.hooks[]?.command] | join(" ")
                                    | test("check-close|check-brief|metrics-event")) | not)))
                    + $d.hooks[$ev]))
    ' "$user_s" "$dist_s" > "$tmp"; then
      echo "settings_merge_apply: jq merge failed" >&2
      rm -f "$tmp"
      return 1
    fi
    if ! mv "$tmp" "$user_s"; then
      echo "settings_merge_apply: failed to write $user_s" >&2
      rm -f "$tmp"
      return 1
    fi
  else
    if ! cp "$dist_s" "$user_s"; then
      echo "settings_merge_apply: failed to copy $dist_s to $user_s" >&2
      return 1
    fi
  fi
  return 0
}
