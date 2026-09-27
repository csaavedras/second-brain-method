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
# CLAUDE.md as a WHOLE FILE is not tracked in the manifest: its state is
# driven by claude_md_has_block() (well-formed / no-markers / corrupt),
# since part of the file's content is legitimately the user's own (outside
# the managed block) and a whole-file sha wouldn't tell "just the block
# changed" apart from "the user edited their own part".
#
# The managed BLOCK's content, though, IS tracked — under a dedicated
# manifest key, "<claude_md_dest>#block" (sha256 of the block's inner
# content right after the last successful write, computed via
# lib/claude-md-block.sh's _block_sha — see its header for why that's not
# just "shasum the extracted block via a bash variable"). That key never
# collides with §4's removed-file sweep: it lives under $claude_dir/
# CLAUDE.md, not under any of commands/, agents/, hooks/ or vault/method/,
# the only prefixes that loop walks. It's what lets a well-formed block
# distinguish "the user hand-edited the block since the last apply"
# (CONFLICT, like every other managed file) from "the block is exactly what
# we installed last time" (safe to replace in place) — see the cmb_rc==0
# branch below.
#
# Design decision — legacy installs with no stored block-sha (F2): an
# install from before this manifest key existed has no baseline to compare
# the current block against, so a hand-edit can't be told apart from "never
# touched". Rather than silently overwrite (the old behavior) or perma-
# conflict (annoying, and never self-heals), a missing stored sha whose
# current block differs from what would be rendered now is treated the
# SAME safe way as a detected hand-edit: back the old block up first, then
# replace it and record a real sha — reported as TAKEN (with the backup
# path), not UPDATED, since "silently overwritten your CLAUDE.md block" is
# exactly the thing every other TAKEN report already means. If the current
# block already matches what would be rendered, nothing is backed up or
# rewritten — the sha is simply recorded so future runs have a baseline.
#
# Design decision — per-language .md overlay (F3a): for the four
# translatable families (claude/CLAUDE.md, claude/commands/*.md,
# claude/agents/*.md, method/*.md) the SOURCE file installed is
# engine/i18n/<lang>/<relpath> when that overlay exists, else it falls
# back to the English engine/<relpath>. Iteration always walks the
# English engine/ tree (it's the source of truth for the file SET — an
# extra file that only exists under i18n/<lang>/ is never installed).
# `.sh` files (hooks, method/scripts) and settings.json are NEVER
# overlaid this way: their text already comes from @@MSG_*@@ tokens
# rendered from engine/i18n/<lang>/messages.env, so translating
# messages.env is enough to translate them — see _apply_src below.

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
  local src_claudemd
  src_claudemd="$(_apply_src "$engine" "$lang" "claude/CLAUDE.md")"
  local rendered_claudemd
  rendered_claudemd="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
  if ! render_file "$src_claudemd" "$rendered_claudemd" "$menv" "$vdisplay" "$vshell"; then
    rm -f "$rendered_claudemd"
    echo "apply: failed to render CLAUDE.md" >&2
    return 1
  fi
  local rendered_block_content
  rendered_block_content="$(cat "$rendered_claudemd")"
  rm -f "$rendered_claudemd"

  local claude_md_block_key="${claude_md_dest}#block"

  if [ "$cmb_rc" -eq 1 ] && [ -s "$claude_md_dest" ]; then
    # old-install adoption: foreign content, no markers at all -> conflict.
    # Build "what --take-new would write" ONCE — the user's existing
    # content with the rendered block appended via claude_md_apply's own
    # no-marker mechanic — and reuse it both for the plain-conflict .new
    # preview and for the actual --take-new write, so the preview is never
    # rebuilt differently from what taking it actually does (F7 in the
    # brief: the old foreign content must never just be discarded).
    local nomarker_tmp
    nomarker_tmp="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
    cp -p "$claude_md_dest" "$nomarker_tmp" || { rm -f "$nomarker_tmp"; echo "apply: mktemp copy failed" >&2; return 1; }
    claude_md_apply "$nomarker_tmp" "$rendered_block_content" \
      || { rm -f "$nomarker_tmp"; echo "apply: failed to build the managed block preview" >&2; return 1; }

    if [ "$take_new" -eq 1 ]; then
      local backup_dest="$backup_root/CLAUDE.md"
      mkdir -p "$(dirname "$backup_dest")" || { rm -f "$nomarker_tmp"; echo "apply: failed to create $(dirname "$backup_dest")" >&2; return 1; }
      cp -p "$claude_md_dest" "$backup_dest" || { rm -f "$nomarker_tmp"; echo "apply: failed to back up $claude_md_dest" >&2; return 1; }
      _apply_write_preserving_mode "$nomarker_tmp" "$claude_md_dest" \
        || { rm -f "$nomarker_tmp"; return 1; }
      rm -f "$claude_md_dest.new" "$nomarker_tmp"
      local new_block_sha
      new_block_sha="$(_block_sha "$claude_md_dest")"
      manifest_set "$claude_md_block_key" "$new_block_sha" || return 1
      printf 'TAKEN\t%s\t%s\n' "$claude_md_dest" "$backup_dest"
    else
      # Plain conflict preview: EXACTLY what --take-new would write (the
      # old foreign content with the block appended once), not the block
      # alone (see F7 above) — the manifest is left untouched (see the
      # header's "conflict manifest policy" note). .new gets the mode the
      # real file would get: $claude_md_dest's own existing mode.
      _apply_write_preserving_mode "$nomarker_tmp" "$claude_md_dest.new" "$claude_md_dest" \
        || { rm -f "$nomarker_tmp"; return 1; }
      rm -f "$nomarker_tmp"
      printf 'CONFLICT\t%s\t%s\n' "$claude_md_dest" "$claude_md_dest.new"
    fi
  elif [ "$cmb_rc" -eq 1 ]; then
    # missing or empty -> straightforward install
    claude_md_apply "$claude_md_dest" "$rendered_block_content" \
      || { echo "apply: failed to write $claude_md_dest" >&2; return 1; }
    rm -f "$claude_md_dest.new"
    local new_block_sha
    new_block_sha="$(_block_sha "$claude_md_dest")"
    manifest_set "$claude_md_block_key" "$new_block_sha" || return 1
    printf 'ADDED\t%s\n' "$claude_md_dest"
  else
    # cmb_rc == 0: well-formed existing block. Detect a hand-edit of the
    # block itself (not the rest of the file, which is always the user's)
    # by comparing the CURRENT block's sha (via _block_sha, byte-exact —
    # see lib/claude-md-block.sh) to the sha recorded after the last
    # successful write.
    local current_sha stored_sha
    current_sha="$(_block_sha "$claude_md_dest")"
    stored_sha="$(manifest_get "$claude_md_block_key")"

    # Build what the file would look like if the block were replaced now —
    # reused to check "would this even change anything" AND, whichever
    # branch below fires, as the exact content written/previewed (so a
    # conflict's preview, a legacy no-baseline replace, and an in-place
    # update are never rebuilt differently from each other). The "would
    # this change anything" check itself compares the two extracted blocks
    # via `cmp` on process substitutions, NOT via bash variable capture
    # (which strips ALL trailing newlines, not just the single one
    # extract_block already trims — the same asymmetry _block_sha exists to
    # avoid, so a hand-edit consisting only of extra blank lines right
    # before END wouldn't be masked here either).
    local probe_tmp rendered_differs
    probe_tmp="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }
    cp -p "$claude_md_dest" "$probe_tmp" 2>/dev/null || : > "$probe_tmp"
    claude_md_apply "$probe_tmp" "$rendered_block_content" \
      || { rm -f "$probe_tmp"; echo "apply: failed to build the managed block preview" >&2; return 1; }
    rendered_differs=1
    if cmp -s <(claude_md_extract_block "$claude_md_dest") <(claude_md_extract_block "$probe_tmp"); then
      rendered_differs=0
    fi

    if [ -n "$stored_sha" ] && [ "$current_sha" != "$stored_sha" ] && [ "$rendered_differs" -eq 1 ]; then
      # the user hand-edited the block since the last apply, AND the
      # rendered block would actually change something -> never clobber,
      # same policy as every other managed file.
      if [ "$take_new" -eq 1 ]; then
        local backup_dest="$backup_root/CLAUDE.md"
        mkdir -p "$(dirname "$backup_dest")" || { rm -f "$probe_tmp"; echo "apply: failed to create $(dirname "$backup_dest")" >&2; return 1; }
        cp -p "$claude_md_dest" "$backup_dest" || { rm -f "$probe_tmp"; echo "apply: failed to back up $claude_md_dest" >&2; return 1; }
        _apply_write_preserving_mode "$probe_tmp" "$claude_md_dest" \
          || { rm -f "$probe_tmp"; return 1; }
        rm -f "$claude_md_dest.new"
        local new_block_sha
        new_block_sha="$(_block_sha "$claude_md_dest")"
        manifest_set "$claude_md_block_key" "$new_block_sha" || { rm -f "$probe_tmp"; return 1; }
        printf 'TAKEN\t%s\t%s\n' "$claude_md_dest" "$backup_dest"
      else
        # conflict: dest untouched, .new written (same mode $claude_md_dest
        # already has); manifest block-key left exactly as found (same
        # policy as generic files — see header).
        _apply_write_preserving_mode "$probe_tmp" "$claude_md_dest.new" "$claude_md_dest" \
          || { rm -f "$probe_tmp"; return 1; }
        printf 'CONFLICT\t%s\t%s\n' "$claude_md_dest" "$claude_md_dest.new"
      fi
      rm -f "$probe_tmp"
    elif [ -z "$stored_sha" ] && [ "$rendered_differs" -eq 1 ]; then
      # Legacy install (predates the block-sha manifest key): no baseline
      # to tell "hand-edited" from "untouched" apart, so treat it the same
      # safe way as a detected hand-edit — back the old block up before
      # replacing it, then record a real sha for every later run (F2 in
      # the brief). Reported as TAKEN (with the backup path), matching
      # every other "we didn't just silently overwrite it" report.
      local backup_dest="$backup_root/CLAUDE.md"
      mkdir -p "$(dirname "$backup_dest")" || { rm -f "$probe_tmp"; echo "apply: failed to create $(dirname "$backup_dest")" >&2; return 1; }
      cp -p "$claude_md_dest" "$backup_dest" || { rm -f "$probe_tmp"; echo "apply: failed to back up $claude_md_dest" >&2; return 1; }
      _apply_write_preserving_mode "$probe_tmp" "$claude_md_dest" \
        || { rm -f "$probe_tmp"; return 1; }
      rm -f "$claude_md_dest.new" "$probe_tmp"
      local new_block_sha
      new_block_sha="$(_block_sha "$claude_md_dest")"
      manifest_set "$claude_md_block_key" "$new_block_sha" || return 1
      printf 'TAKEN\t%s\t%s\n' "$claude_md_dest" "$backup_dest"
    else
      # Unedited block (stored sha matches current), or no stored sha but
      # the rendered block wouldn't change anything anyway -> safe to
      # replace in place. Reuses the probe already built above instead of
      # running claude_md_apply a second time (F10 in the brief).
      rm -f "$claude_md_dest.new"
      if [ "$rendered_differs" -eq 1 ]; then
        _apply_write_preserving_mode "$probe_tmp" "$claude_md_dest" \
          || { rm -f "$probe_tmp"; return 1; }
        printf 'UPDATED\t%s\n' "$claude_md_dest"
      fi
      rm -f "$probe_tmp"
      local new_block_sha
      new_block_sha="$(_block_sha "$claude_md_dest")"
      manifest_set "$claude_md_block_key" "$new_block_sha" || return 1
    fi
  fi

  # === 2. settings.json — always merged, unconditionally, every run ========
  settings_merge_apply "$claude_dir/settings.json" "$engine/claude/settings.json" \
    || { echo "apply: settings.json merge failed" >&2; return 1; }
  printf 'MERGED\t%s\n' "$claude_dir/settings.json"

  # === 3. generic managed files ==============================================
  local current_dests
  current_dests="$(mktemp)" || { echo "apply: mktemp failed" >&2; return 1; }

  local f name dest src
  for f in "$engine"/claude/commands/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$claude_dir/commands/$name"
    src="$(_apply_src "$engine" "$lang" "claude/commands/$name")"
    _apply_process_file "$src" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "commands/$name" "$take_new" 0 \
      || { rm -f "$current_dests"; return 1; }
    printf '%s\n' "$dest" >> "$current_dests"
  done

  for f in "$engine"/claude/agents/*.md; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    dest="$claude_dir/agents/$name"
    src="$(_apply_src "$engine" "$lang" "claude/agents/$name")"
    _apply_process_file "$src" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "agents/$name" "$take_new" 0 \
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
    src="$(_apply_src "$engine" "$lang" "method/$name")"
    _apply_process_file "$src" "$dest" "$menv" "$vdisplay" "$vshell" "$backup_root" "method/$name" "$take_new" 0 \
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
  # Prefix-based: "$claude_md_block_key" ("$claude_dir/CLAUDE.md#block")
  # never matches any of these four prefixes (CLAUDE.md lives directly
  # under $claude_dir, not under commands/agents/hooks/ nor vault/method/),
  # so this sweep can never remove/orphan the block's tracked sha.
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

# _apply_src <engine> <lang> <relpath> — echoes the source path to install
# for a translatable .md file: engine/i18n/<lang>/<relpath> if that overlay
# exists as a regular file, else engine/<relpath> (English fallback). Only
# call this for the four translatable families listed in the header
# comment above — never for .sh files or settings.json.
_apply_src() {
  local engine="$1" lang="$2" relpath="$3" overlay
  overlay="$engine/i18n/$lang/$relpath"
  if [ -f "$overlay" ]; then
    printf '%s\n' "$overlay"
  else
    printf '%s\n' "$engine/$relpath"
  fi
}

# _apply_write_preserving_mode <src> <write_dest> [<mode_reference_dest>] —
# atomically writes <src>'s content to <write_dest> (temp file in the same
# directory + mv, same style as claude_md_apply/backup_write), with the
# mode <mode_reference_dest> (default: <write_dest> itself) would get per
# preserve_mode_or_default: its own EXISTING mode when it's already a file
# on disk, else 0644 (CLAUDE.md and its .new sibling are always plain
# files, never chmod_x). Passing a different <mode_reference_dest> than
# <write_dest> is what lets a CLAUDE.md.new preview end up with the mode
# the REAL file would get, not whatever mktemp/cp would otherwise leave it
# at (F4/F8 in the brief). Every direct CLAUDE.md write in §1 above goes
# through this instead of a bare `cp`/`cat >` so none of them can leak a
# tmp file's mktemp-default 0600.
_apply_write_preserving_mode() {
  local src="$1" dest="$2" mode_ref="${3:-$2}" dir mode tmp
  dir="$(dirname "$dest")"
  mkdir -p "$dir" || { echo "apply: failed to create $dir" >&2; return 1; }
  mode="$(preserve_mode_or_default "$mode_ref" 0)"
  tmp="$(mktemp "$dir/.apply-write.XXXXXX")" || { echo "apply: mktemp failed" >&2; return 1; }
  if ! cp "$src" "$tmp"; then
    echo "apply: failed to stage write for $dest" >&2
    rm -f "$tmp"
    return 1
  fi
  chmod "$mode" "$tmp"
  if ! mv "$tmp" "$dest"; then
    echo "apply: failed to write $dest" >&2
    rm -f "$tmp"
    return 1
  fi
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
      rm -f "$rendered" "$dest.new"
      return 0
    fi
    backup_write "$rendered" "$dest" "" || { rm -f "$rendered"; return 1; }
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    rm -f "$dest.new"
    printf 'UPDATED\t%s\n' "$dest"
    rm -f "$rendered"
    return 0
  fi

  # conflict candidate: no manifest entry, or current sha differs from it
  if cmp -s "$rendered" "$dest"; then
    # dest already happens to match what we'd install: record it as owned
    # going forward, but nothing actually changed on disk, so no report
    # line (a bare "UPDATED" here would be a false positive for a no-op).
    sha_now="$(manifest_sha256 "$dest")"
    manifest_set "$dest" "$sha_now" || { rm -f "$rendered"; return 1; }
    rm -f "$rendered" "$dest.new"
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
