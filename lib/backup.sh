# lib/backup.sh — content-aware atomic writes with backup-on-change.
# Sourceable library: sourcing this file has no side effects, it only
# defines functions. bash 3.2 safe (no associative arrays, no
# ${var//pat/rep} on data-derived values). macOS only (uses BSD `stat`).
#
# This library has zero path-policy: callers decide where backups live
# (e.g. under "<CLAUDE_HOME>/.second-brain/backups/<utc_timestamp>/...");
# it only performs the mechanical compare/backup/write.
#
# Usage:
#   utc_timestamp
#     -> prints a UTC timestamp as YYYYMMDDTHHMMSSZ, suitable for building
#        a backup root directory name.
#
#   backup_write <src_rendered_file> <dest> <backup_dest_path_or_empty>
#     - <dest> refused if it, or its immediate parent directory, is a
#       symlink (non-zero, stderr, nothing written) — ports the
#       symlink-refusal idea from install.py's check_destination(), scoped
#       to <dest>'s own directory rather than every ancestor up to "/":
#       OS-level symlinks that sit above any realistic managed root (macOS
#       "/var" -> "/private/var", "/tmp" -> "/private/tmp") must not cause
#       a false refusal — every mktemp-based CLAUDE_HOME used by this
#       repo's own tests lives under one of those. Checking <dest> and its
#       direct parent still catches the real attack this guards against:
#       a managed directory (e.g. "commands/") replaced by a symlink.
#     - <dest> doesn't exist          -> written directly (no backup
#                                         possible/needed), mode 0644, +x if
#                                         <src_rendered_file> was executable
#                                         (0755) — NOT whatever mode the
#                                         mktemp'd <src_rendered_file>/temp
#                                         file happened to have (mktemp
#                                         defaults to 0600).
#     - <dest> content == src content (byte compare, cmp -s)
#                                      -> no-op: no backup, no write,
#                                         return 0.
#     - <dest> content differs from src, and <backup_dest_path_or_empty>
#       is non-empty                  -> the OLD <dest> is copied there
#                                         first (parent dirs created,
#                                         mode preserved), THEN <dest> is
#                                         atomically overwritten with
#                                         <src_rendered_file>'s content,
#                                         mode 0644, +x preserved if <dest>
#                                         previously had it.
#     - <dest> content differs, <backup_dest_path_or_empty> is empty
#                                      -> overwritten as above, no backup
#                                         made.
#     All writes are temp-file (in <dest>'s directory) + mv, so a failing
#     branch never leaves <dest> partially written.

utc_timestamp() {
  date -u '+%Y%m%dT%H%M%SZ'
}

backup_write() {
  local src="$1" dest="$2" backup="$3"
  local dest_dir backup_dir tmp dest_parent dest_existed

  if [ -z "${src:-}" ] || [ -z "${dest:-}" ]; then
    echo "backup_write: usage: backup_write <src_rendered_file> <dest> <backup_dest_path_or_empty>" >&2
    return 1
  fi
  [ -f "$src" ] || { echo "backup_write: source not found: $src" >&2; return 1; }

  # Refuse if dest itself, or its immediate parent directory, is a symlink
  # — ported from install.py's check_destination() idea, scoped to just
  # these two (see header comment: a full ancestor walk to "/" false-
  # positives on macOS's own "/var" and "/tmp" symlinks).
  if [ -L "$dest" ]; then
    echo "backup_write: refusing symlink destination: $dest" >&2
    return 1
  fi
  dest_parent="$(dirname "$dest")"
  if [ -L "$dest_parent" ]; then
    echo "backup_write: refusing symlink destination directory: $dest_parent" >&2
    return 1
  fi

  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir" || { echo "backup_write: failed to create $dest_dir" >&2; return 1; }

  dest_existed=0
  [ -e "$dest" ] && dest_existed=1

  if [ "$dest_existed" -eq 1 ] && cmp -s "$src" "$dest"; then
    return 0
  fi

  if [ "$dest_existed" -eq 1 ] && [ -n "${backup:-}" ]; then
    backup_dir="$(dirname "$backup")"
    mkdir -p "$backup_dir" || { echo "backup_write: failed to create $backup_dir" >&2; return 1; }
    if ! cp -p "$dest" "$backup"; then
      echo "backup_write: failed to back up $dest to $backup" >&2
      return 1
    fi
  fi

  tmp="$(mktemp "$dest_dir/.backup_write.XXXXXX")" || { echo "backup_write: mktemp failed" >&2; return 1; }
  if ! cp "$src" "$tmp"; then
    echo "backup_write: failed to stage write for $dest" >&2
    rm -f "$tmp"
    return 1
  fi
  # mktemp creates $tmp as 0600; `cp` (no -p) on macOS otherwise carries
  # that restrictive mode straight through to $dest. Force the real target
  # mode explicitly instead of relying on cp/mktemp defaults: 0644 base,
  # +x preserved when it should be (0755 for hooks/scripts).
  chmod 644 "$tmp"

  if [ "$dest_existed" -eq 1 ]; then
    if [ -x "$dest" ]; then
      chmod +x "$tmp"
    fi
  else
    if [ -x "$src" ]; then
      chmod +x "$tmp"
    fi
  fi

  if ! mv "$tmp" "$dest"; then
    echo "backup_write: failed to write $dest" >&2
    rm -f "$tmp"
    return 1
  fi
  return 0
}
