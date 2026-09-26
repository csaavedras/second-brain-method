# lib/apply.sh — the core upgrade algorithm shared by `sbm install` and
# `sbm update`. For every file the method manages, decides per-file whether
# to install it fresh, update it in place, flag a conflict (write a `.new`
# sibling, leave dest untouched) or, with --take-new, take the new rendered
# content (backing up the old one first). Sourceable library: sourcing this
# file has no side effects, it only defines apply() and a private helper.
# bash 3.2 safe (no associative arrays, no ${var//pat/rep} on data-derived
# values). Requires: lib/render.sh, lib/manifest.sh, lib/claude-md-block.sh,
# lib/backup.sh and lib/settings-merge.sh already sourced by the caller.
#
# Usage:
#   apply <lang> <claude_dir> <vault> [--take-new]
#
# Prints one report line per managed file to stdout, tab-separated:
#   <STATUS>\t<dest-path>[\t<new-or-backup-path>]
# STATUS in ADDED UPDATED CONFLICT TAKEN DELETED ORPHANED MERGED.
#
# Returns 0 normally. The ONLY case where apply() itself returns non-zero
# is an existing CLAUDE.md with a corrupt managed block (more than one
# BEGIN/END marker, or END before BEGIN) — that is checked FIRST, before
# anything else is touched, so a hard-abort here never leaves a partial
# apply behind. Any other non-zero return (e.g. render_file/backup_write
# failing on an I/O error) is an unexpected failure, surfaced the same way
# for safety, but is not part of the designed control flow.
#
# Design decision — conflict manifest policy (left to the implementer by
# the brief, documented here): when a CONFLICT is reported and --take-new
# is NOT given, the manifest entry for that path is left EXACTLY as found
# (untouched if it already had one, still absent if it did not) instead of
# being backfilled with sha256(dest). Backfilling it would make dest look
# "owned and untouched since last apply" on the very next plain apply run
# (the branch right above the conflict branch below), which writes with an
# EMPTY backup path (by design — that branch assumes it's a file the
# method already owns) — i.e. it would silently overwrite the user's/
# foreign content with no backup on a later run. Leaving the manifest
# alone keeps re-flagging the same file as CONFLICT on every subsequent
# run until the user resolves it by hand or via --take-new, which is the
# safe behavior for a tool whose entire job is to never clobber edits
# silently.
#
# Design decision — settings.json is always MERGED unconditionally, every
# run (matches install.sh's original merge-only behavior; not tracked in
# the manifest, never CONFLICT/TAKEN — merges are idempotent by design).
#
# CLAUDE.md is NOT tracked in the manifest either: its state is fully
# driven by claude_md_has_block() (well-formed / no-markers / corrupt),
# since part of the file's content is legitimately the user's own (outside
# the managed block) and a whole-file sha wouldn't tell "just the block
# changed" apart from "the user edited their own part".

apply() {
  local lang="$1" claude_dir="$2" vault="$3" mode="${4:-}"
  local take_new=0
  [ "$mode" = "--take-new" ] && take_new=1

  if [ -z "${lang:-}" ] || [ -z "${claude_dir:-}" ] || [ -z "${vault:-}" ]; then
    echo "apply: usage: apply <lang> <claude_dir> <vault> [--take-new]" >&2
    return 1
  fi

  local apply_lib_dir repo_root engine menv
  apply_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$apply_lib_dir/.." && pwd)"
  engine="$repo_root/engine"
  menv="$engine/i18n/$lang/messages.env"
  [ -f "$menv" ] || { echo "apply: messages file not found: $menv" >&2; return 1; }

  # --- 0. CLAUDE.md corruption gate: checked FIRST, before touching anything
  local claude_md_dest="$claude_dir/CLAUDE.md"
  local cmb_rc
  claude_md_has_block "$claude_md_dest"
  cmb_rc=$?
  if [ "$cmb_rc" -eq 2 ]; then
    echo "apply: $claude_md_dest has a corrupt managed block (multiple or unbalanced BEGIN/END markers) — aborting before touching anything. Fix it by hand (or restore from a backup) and re-run." >&2
    return 1
  fi

  # --- vault path display/shell forms (same convention as install.sh) ------
  local vdisplay vshell
  if [[ "$vault" == "$HOME/"* ]]; then
    vdisplay="~/${vault#"$HOME"/}"
    vshell="\$HOME/${vault#"$HOME"/}"
  else
    vdisplay="$vault"
    vshell="$vault"
  fi

  local backup_root
  backup_root="$claude_dir/.second-brain/backups/$(utc_timestamp)"

  # === 1. CLAUDE.md ==========================================================
  local rendered_claudemd
  rendered_claudemd="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
  if ! render_file "$engine/claude/CLAUDE.md" "$rendered_claudemd" "$menv" "$vdisplay" "$vshell"; then
    rm -f "$rendered_claudemd"
    echo "apply: failed to render CLAUDE.md" >&2
    return 1
  fi
  local rendered_block_content
  rendered_block_content="$(cat "$rendered_claudemd")"
  rm -f "$rendered_claudemd"

  if [ "$cmb_rc" -eq 1 ] && [ -s "$claude_md_dest" ]; then
    # old-install adoption: foreign content, no markers at all -> conflict
    if [ "$take_new" -eq 1 ]; then
      local backup_dest="$backup_root/CLAUDE.md"
      mkdir -p "$(dirname "$backup_dest")" || { echo "apply: failed to create $(dirname "$backup_dest")" >&2; return 1; }
      cp -p "$claude_md_dest" "$backup_dest" || { echo "apply: failed to back up $claude_md_dest" >&2; return 1; }
      # take-new means "discard the old file" (it's safely backed up above),
      # matching how every other managed file is fully replaced on
      # --take-new. Build the fresh block against an EMPTY file (not
      # against $claude_md_dest) so the old foreign content isn't appended
      # underneath it — claude_md_apply's own mechanic appends onto
      # existing no-marker content by design, which is correct for the
      # plain-conflict .new preview but wrong here.
      local take_new_tmp
      take_new_tmp="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
      rm -f "$take_new_tmp"
      : > "$take_new_tmp"
      claude_md_apply "$take_new_tmp" "$rendered_block_content" \
        || { rm -f "$take_new_tmp"; echo "apply: failed to build the managed block" >&2; return 1; }
      cat "$take_new_tmp" > "$claude_md_dest" \
        || { rm -f "$take_new_tmp"; echo "apply: failed to write $claude_md_dest" >&2; return 1; }
      rm -f "$take_new_tmp"
      rm -f "$claude_md_dest.new"
      printf 'TAKEN\t%s\t%s\n' "$claude_md_dest" "$backup_dest"
    else
      local empty_tmp
      empty_tmp="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
      rm -f "$empty_tmp"
      : > "$empty_tmp"
      claude_md_apply "$empty_tmp" "$rendered_block_content" \
        || { rm -f "$empty_tmp"; echo "apply: failed to build the managed block preview" >&2; return 1; }
      cp "$empty_tmp" "$claude_md_dest.new" || { rm -f "$empty_tmp"; echo "apply: failed to write $claude_md_dest.new" >&2; return 1; }
      rm -f "$empty_tmp"
      printf 'CONFLICT\t%s\t%s\n' "$claude_md_dest" "$claude_md_dest.new"
    fi
  elif [ "$cmb_rc" -eq 1 ]; then
    # missing or empty -> straightforward install
    claude_md_apply "$claude_md_dest" "$rendered_block_content" \
      || { echo "apply: failed to write $claude_md_dest" >&2; return 1; }
    printf 'ADDED\t%s\n' "$claude_md_dest"
  else
    # cmb_rc == 0: well-formed existing block -> in-place block replace
    local before_copy
    before_copy="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
    cp "$claude_md_dest" "$before_copy" 2>/dev/null || : > "$before_copy"
    claude_md_apply "$claude_md_dest" "$rendered_block_content" \
      || { rm -f "$before_copy"; echo "apply: failed to write $claude_md_dest" >&2; return 1; }
    if ! cmp -s "$before_copy" "$claude_md_dest"; then
      printf 'UPDATED\t%s\n' "$claude_md_dest"
    fi
    rm -f "$before_copy"
  fi

  # === 2. settings.json — always merged, unconditionally, every run ========
  settings_merge_apply "$claude_dir/settings.json" "$engine/claude/settings.json" \
    || { echo "apply: settings.json merge failed" >&2; return 1; }
  printf 'MERGED\t%s\n' "$claude_dir/settings.json"

  # === 3. generic managed files ==============================================
  local current_dests
  current_dests="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }

  local f name dest
  for f in "$engine"/claude/commands/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$claude_dir/commands/$name"
    _apply_process_file "$f" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "commands/$name" "$take_new" 0 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  for f in "$engine"/claude/agents/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$claude_dir/agents/$name"
    _apply_process_file "$f" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "agents/$name" "$take_new" 0 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  for f in "$engine"/claude/hooks/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$claude_dir/hooks/$name"
    _apply_process_file "$f" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "hooks/$name" "$take_new" 1 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  for f in "$engine"/method/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$vault/method/$name"
    _apply_process_file "$f" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "method/$name" "$take_new" 0 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  for f in "$engine"/method/scripts/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$vault/method/scripts/$name"
    _apply_process_file "$f" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "method/scripts/$name" "$take_new" 1 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  # === 4. files removed from the engine (manifest-tracked, no longer produced)
  local mpath prefix_root key manifest_sha_removed cur_sha_removed
  mpath="$(manifest_path)"
  if [ -f "$mpath" ]; then
    for prefix_root in "$claude_dir/commands/" "$claude_dir/agents/" "$claude_dir/hooks/" "$vault/method/"; do
      while IFS= read -r key; do
        [ -n "$key" ] || continue
        if grep -qxF "$key" "$current_dests" 2>/dev/null; then
          continue
        fi
        if [ -f "$key" ]; then
          manifest_sha_removed="$(manifest_get "$key")"
          cur_sha_removed="$(manifest_sha256 "$key")"
          if [ -n "$manifest_sha_removed" ] && [ "$manifest_sha_removed" = "$cur_sha_removed" ]; then
            rm -f "$key"
            manifest_remove "$key"
            printf 'DELETED\t%s\n' "$key"
          else
            printf 'ORPHANED\t%s\n' "$key"
          fi
        else
          # already gone from disk but still tracked -> just clean the manifest
          manifest_remove "$key"
        fi
      done < <(jq -r --arg p "$prefix_root" 'keys[] | select(startswith($p))' "$mpath")
    done
  fi

  rm -f "$current_dests"
  return 0
}

# _apply_process_file <src> <dest> <menv> <vdisplay> <vshell> <backup_root>
#                      <relpath> <take_new 0|1> <chmod_x 0|1>
# Private helper for the generic per-file loop in apply(). Prints its
# report line(s) to stdout; returns non-zero only on unexpected render/
# write failure.
_apply_process_file() {
  local src="$1" dest="$2" menv="$3" vdisplay="$4" vshell="$5" backup_root="$6" \
        relpath="$7" take_new="$8" chmod_x="$9"
  local rendered sha_now manifest_sha dest_sha_before

  rendered="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
  if ! render_file "$src" "$rendered" "$menv" "$vdisplay" "$vshell"; then
    rm -f "$rendered"
    echo "apply: failed to render $src" >&2
    return 1
  fi
  [ "$chmod_x" -eq 1 ] && chmod +x "$rendered"

  if [ ! -e "$dest" ]; then
    backup_write "$rendered" "$dest" "" || { rm -f "$rendered"; return 1; }
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    printf 'ADDED\t%s\n' "$dest"
    rm -f "$rendered"
    return 0
  fi

  manifest_sha="$(manifest_get "$dest")"
  dest_sha_before="$(manifest_sha256 "$dest")"

  if [ -n "$manifest_sha" ] && [ "$manifest_sha" = "$dest_sha_before" ]; then
    # owned by the method, untouched since the last apply
    if cmp -s "$rendered" "$dest"; then
      rm -f "$rendered"
      return 0
    fi
    backup_write "$rendered" "$dest" "" || { rm -f "$rendered"; return 1; }
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    printf 'UPDATED\t%s\n' "$dest"
    rm -f "$rendered"
    return 0
  fi

  # conflict candidate: no manifest entry, or current sha differs from it
  if cmp -s "$rendered" "$dest"; then
    # dest already happens to match what we'd install -> nothing to flag
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    printf 'UPDATED\t%s\n' "$dest"
    rm -f "$rendered"
    return 0
  fi

  if [ "$take_new" -eq 1 ]; then
    local backup_dest="$backup_root/$relpath"
    backup_write "$rendered" "$dest" "$backup_dest" || { rm -f "$rendered"; return 1; }
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    rm -f "$dest.new"
    printf 'TAKEN\t%s\t%s\n' "$dest" "$backup_dest"
    rm -f "$rendered"
    return 0
  fi

  # plain conflict: write dest.new, leave dest and the manifest untouched
  backup_write "$rendered" "$dest.new" "" || { rm -f "$rendered"; return 1; }
  printf 'CONFLICT\t%s\t%s\n' "$dest" "$dest.new"
  rm -f "$rendered"
  return 0
}
