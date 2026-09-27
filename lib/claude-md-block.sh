# lib/claude-md-block.sh — detect and apply the Second Brain Method's
# managed block inside a CLAUDE.md-like file, delimited by CLAUDE_MD_BEGIN
# / CLAUDE_MD_END. Sourceable library: sourcing this file has no side
# effects beyond defining the two readonly marker constants below and
# functions. bash 3.2 safe (no associative arrays, no ${var//pat/rep} on
# data-derived content — the actual text splicing is done with perl using
# plain string ops, same approach as lib/render.sh, so arbitrary content
# containing shell metacharacters can never corrupt the result).
#
# Design decision (documented per brief): claude_md_apply() writes
# DIRECTLY to <file>, atomically (temp file in the same directory + mv,
# preserving <file>'s existing permission bits when it already existed),
# matching render_file's style. It does not print the result to stdout.
#
# Policy note: claude_md_apply() is a pure mechanic, not a policy. It does
# NOT decide "conflict" vs "fresh install" for the "file has content, no
# markers" case — it always appends there. Callers (the CLI's `apply`
# logic, built separately) MUST call claude_md_has_block() FIRST and route
# the "has content, no markers" case through their own conflict/.new
# handling instead of calling claude_md_apply() directly on a foreign file
# if silent appending isn't the desired behavior.
#
# Usage:
#   claude_md_has_block <file>
#     exit 0  -> exactly one BEGIN and one END, BEGIN before END
#     exit 1  -> file doesn't exist, or has no markers at all (normal,
#                expected case — e.g. a fresh CLAUDE.md — NOT an error)
#     exit 2  -> corrupt block: more than one BEGIN, more than one END,
#                END before BEGIN, or unbalanced BEGIN/END counts
#
#   claude_md_apply <file> <new_block_content>
#     Computes the managed block as:
#       CLAUDE_MD_BEGIN
#       <new_block_content, trailing whitespace trimmed>
#       CLAUDE_MD_END
#     - corrupt existing block (per above)     -> non-zero exit, stderr
#                                                  error, <file> untouched.
#     - exactly one well-ordered block present -> replaces just that span
#                                                  in place; everything
#                                                  before/after is kept
#                                                  byte-for-byte.
#     - no markers at all (file missing, empty,
#       or plain content)                      -> file missing/empty: file
#                                                  becomes only the block;
#                                                  file has content: block
#                                                  is appended after it,
#                                                  separated by a blank
#                                                  line (matching the
#                                                  install.py prior-art
#                                                  behavior: existing +
#                                                  "\n\n" + block + "\n"
#                                                  when existing doesn't
#                                                  already end in "\n\n").
#     Returns 0 on success (file written), non-zero on failure (file
#     untouched).
#
#   claude_md_extract_block <file>
#     Prints just the managed block's inner content (between the BEGIN/END
#     marker lines, exclusive of the markers themselves and of the single
#     blank-line-equivalent newline right after BEGIN / right before END —
#     i.e. the same string shape apply() passes IN as <new_block_content>
#     to claude_md_apply(), so sha256-ing this output is comparable across
#     "what's on disk" vs "what we're about to render"). Same marker
#     semantics as claude_md_has_block(): exit 1 (nothing printed) unless
#     <file> has exactly one well-ordered BEGIN/END pair.

CLAUDE_MD_BEGIN='<!-- BEGIN SECOND BRAIN METHOD -->'
CLAUDE_MD_END='<!-- END SECOND BRAIN METHOD -->'

claude_md_has_block() {
  local file="$1" begin_count end_count begin_line end_line

  [ -n "${file:-}" ] && [ -f "$file" ] || return 1

  begin_count="$(grep -Fc -- "$CLAUDE_MD_BEGIN" "$file")"
  end_count="$(grep -Fc -- "$CLAUDE_MD_END" "$file")"

  if [ "$begin_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
    return 1
  fi
  if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
    return 2
  fi

  begin_line="$(grep -Fn -- "$CLAUDE_MD_BEGIN" "$file" | head -1 | cut -d: -f1)"
  end_line="$(grep -Fn -- "$CLAUDE_MD_END" "$file" | head -1 | cut -d: -f1)"
  if [ "$end_line" -lt "$begin_line" ]; then
    return 2
  fi
  return 0
}

claude_md_extract_block() {
  local file="$1"
  claude_md_has_block "$file" || return 1

  CMB_FILE="$file" CMB_BEGIN="$CLAUDE_MD_BEGIN" CMB_END="$CLAUDE_MD_END" perl -e '
    my $file  = $ENV{CMB_FILE};
    my $begin = $ENV{CMB_BEGIN};
    my $end   = $ENV{CMB_END};

    open(my $fh, "<", $file) or exit 1;
    local $/;
    my $existing = <$fh>;
    close($fh);
    $existing = "" unless defined $existing;

    my $bidx = index($existing, $begin);
    my $eidx = index($existing, $end);
    exit 1 if $bidx < 0 || $eidx < 0 || $eidx < $bidx;

    my $inner_start = $bidx + length($begin);
    my $inner = substr($existing, $inner_start, $eidx - $inner_start);
    $inner =~ s/\A\n//;
    $inner =~ s/\n\z//;
    print $inner;
  '
}

claude_md_apply() {
  local file="$1" content="$2"
  local dir tmp errtmp rc was_existing perm

  if [ -z "${file:-}" ]; then
    echo "claude_md_apply: usage: claude_md_apply <file> <new_block_content>" >&2
    return 1
  fi

  dir="$(dirname "$file")"
  mkdir -p "$dir" || { echo "claude_md_apply: failed to create $dir" >&2; return 1; }

  was_existing=0
  [ -f "$file" ] && was_existing=1

  tmp="$(mktemp "$dir/.claude-md-block.XXXXXX")" || { echo "claude_md_apply: mktemp failed" >&2; return 1; }
  errtmp="$(mktemp "$dir/.claude-md-block-err.XXXXXX")" || {
    rm -f "$tmp"
    echo "claude_md_apply: mktemp failed" >&2
    return 1
  }

  CMB_FILE="$file" CMB_CONTENT="$content" \
  CMB_BEGIN="$CLAUDE_MD_BEGIN" CMB_END="$CLAUDE_MD_END" \
  perl > "$tmp" 2>"$errtmp" <<'CMB_PERL_EOF'
use strict;
use warnings;

my $file    = $ENV{CMB_FILE};
my $content = defined $ENV{CMB_CONTENT} ? $ENV{CMB_CONTENT} : '';
my $begin   = $ENV{CMB_BEGIN};
my $end     = $ENV{CMB_END};

my $existing = '';
if (open(my $fh, '<', $file)) {
  local $/;
  my $slurp = <$fh>;
  $existing = defined $slurp ? $slurp : '';
  close($fh);
}

# rstrip trailing whitespace from the incoming content, like Python's
# str.rstrip() (trailing spaces/tabs/newlines all removed).
$content =~ s/\s+\z//;

my $block = $begin . "\n" . $content . "\n" . $end;

my $begin_count = () = $existing =~ /\Q$begin\E/g;
my $end_count   = () = $existing =~ /\Q$end\E/g;

if ($begin_count == 0 && $end_count == 0) {
  my $out;
  if ($existing eq '') {
    $out = $block . "\n";
  } else {
    my $sep = ($existing =~ /\n\n\z/) ? '' : "\n\n";
    $out = $existing . $sep . $block . "\n";
  }
  print $out;
  exit 0;
}

if ($begin_count != 1 || $end_count != 1) {
  print STDERR "claude_md_apply: corrupt managed block in $file (BEGIN x$begin_count, END x$end_count)\n";
  exit 2;
}

my $bidx = index($existing, $begin);
my $eidx = index($existing, $end);
if ($eidx < $bidx) {
  print STDERR "claude_md_apply: managed block markers reversed in $file\n";
  exit 2;
}

my $out = substr($existing, 0, $bidx) . $block . substr($existing, $eidx + length($end));
print $out;
exit 0;
CMB_PERL_EOF
  rc=$?

  if [ "$rc" -ne 0 ]; then
    cat "$errtmp" >&2
    rm -f "$tmp" "$errtmp"
    return 1
  fi
  rm -f "$errtmp"

  # New file: 0644 (mktemp would leave it 0600). Existing: keep its mode.
  perm="644"
  if [ "$was_existing" -eq 1 ]; then
    perm="$(stat -f '%Lp' "$file" 2>/dev/null)"
  fi

  if ! mv "$tmp" "$file"; then
    echo "claude_md_apply: failed to write $file" >&2
    rm -f "$tmp"
    return 1
  fi
  [ -n "${perm:-}" ] && chmod "$perm" "$file" 2>/dev/null

  return 0
}
