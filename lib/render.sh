# lib/render.sh — literal (metachar-safe) renderer for the method's
# @@MSG_*@@ and @@VAULT@@ placeholders. Sourceable library: sourcing this
# file has no side effects, it only defines render_file(). bash 3.2 safe
# (no associative arrays, no ${var//pat/rep}).
#
# Usage:
#   render_file <src> <dst> <messages_env> <vault_display> <vault_shell>
#
#   src            file to render (may equal dst for in-place rendering)
#   dst            file to write (temp-file + move; preserves +x bit)
#   messages_env   path to a messages.env (KEY=value per line, see
#                  engine/i18n/en/messages.env for the format)
#   vault_display  vault path as shown to humans (e.g. "~/second-brain")
#   vault_shell    vault path as a shell-runtime expression (e.g.
#                  "$HOME/second-brain" or a literal absolute path)
#
# Rules:
#   - @@MSG_X@@  -> value of MSG_X from messages_env, escaped for a shell
#                   single-quoted context ( ' -> '\'' ).
#   - @@VAULT@@ in *.md  -> vault_display, literally.
#   - @@VAULT@@ in *.sh  -> sits inside "..."; if vault_shell starts with
#                   "$HOME/" that prefix is kept unescaped (so it expands
#                   at runtime) and the remainder is escaped for a double
#                   quoted context; otherwise the whole value is escaped.
#   - Non-zero exit, message on stderr, dst left untouched if a @@MSG_*@@
#     key used in src is missing from messages_env, or if any
#     @@[A-Z0-9_]+@@ token remains after rendering.
#
# The substitution itself is literal (perl with plain string ops — no sed,
# no shell ${var//pat/rep}) so vault paths or messages containing shell
# metacharacters (&, #, \, $, `, ...) can never corrupt the output.

render_file() {
  local src="$1" dst="$2" menv="$3" vdisplay="$4" vshell="$5"

  if [ -z "${src:-}" ] || [ -z "${dst:-}" ] || [ -z "${menv:-}" ]; then
    echo "render_file: usage: render_file <src> <dst> <messages_env> <vault_display> <vault_shell>" >&2
    return 1
  fi
  [ -f "$src" ]  || { echo "render_file: source not found: $src" >&2; return 1; }
  [ -f "$menv" ] || { echo "render_file: messages file not found: $menv" >&2; return 1; }

  local is_sh=0
  case "$src" in
    *.sh) is_sh=1 ;;
  esac

  local tmp errtmp
  tmp="$(mktemp)" || { echo "render_file: mktemp failed" >&2; return 1; }
  errtmp="$(mktemp)" || { rm -f "$tmp"; echo "render_file: mktemp failed" >&2; return 1; }

  RENDER_SRC="$src" RENDER_MENV="$menv" RENDER_VDISPLAY="$vdisplay" \
  RENDER_VSHELL="$vshell" RENDER_ISSH="$is_sh" \
  perl > "$tmp" 2>"$errtmp" <<'RENDER_PERL_EOF'
use strict;
use warnings;

my $src      = $ENV{RENDER_SRC};
my $menv     = $ENV{RENDER_MENV};
my $vdisplay = defined $ENV{RENDER_VDISPLAY} ? $ENV{RENDER_VDISPLAY} : '';
my $vshell   = defined $ENV{RENDER_VSHELL}   ? $ENV{RENDER_VSHELL}   : '';
my $is_sh    = (defined $ENV{RENDER_ISSH} ? $ENV{RENDER_ISSH} : '0') eq '1';

my %msg;
open(my $mh, '<', $menv) or do {
  print STDERR "render_file: cannot open messages file: $menv\n";
  exit 1;
};
while (my $line = <$mh>) {
  chomp $line;
  next if $line =~ /^\s*#/;
  next if $line =~ /^\s*$/;
  my $eq = index($line, '=');
  next if $eq < 0;
  my $key = substr($line, 0, $eq);
  my $val = substr($line, $eq + 1);
  $msg{$key} = $val;
}
close($mh);

open(my $sh, '<', $src) or do {
  print STDERR "render_file: cannot open source file: $src\n";
  exit 1;
};
my $content = do { local $/; <$sh> };
$content = '' unless defined $content;
close($sh);

my $vault_repl = $is_sh ? $vshell : $vdisplay;
my $missing = 0;

my $esc_dq = sub {
  my ($v) = @_;
  $v =~ s/\\/\\\\/g;
  $v =~ s/"/\\"/g;
  $v =~ s/\$/\\\$/g;
  $v =~ s/`/\\`/g;
  return $v;
};

my $replace = sub {
  my ($name) = @_;
  if ($name =~ /^MSG_[A-Z0-9_]+$/) {
    if (!exists $msg{$name}) {
      print STDERR "render_file: missing key $name (used in $src) — not found in $menv\n";
      $missing = 1;
      return "\@\@$name\@\@";
    }
    my $v = $msg{$name};
    $v =~ s/'/'\\''/g;
    return $v;
  } elsif ($name eq 'VAULT') {
    if ($is_sh) {
      my $v = $vault_repl;
      my $home_prefix = '$HOME/';
      if (index($v, $home_prefix) == 0) {
        my $rest = substr($v, length($home_prefix));
        return $home_prefix . $esc_dq->($rest);
      } else {
        return $esc_dq->($v);
      }
    } else {
      return $vault_repl;
    }
  } else {
    return "\@\@$name\@\@";
  }
};

$content =~ s/\@\@([A-Z0-9_]+)\@\@/$replace->($1)/ge;

if ($missing) {
  exit 1;
}
if ($content =~ /\@\@[A-Z0-9_]+\@\@/) {
  print STDERR "render_file: unresolved placeholder(s) remain in $src\n";
  exit 1;
}

print $content;
RENDER_PERL_EOF
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    cat "$errtmp" >&2
    rm -f "$tmp" "$errtmp"
    return 1
  fi
  cat "$errtmp" >&2
  rm -f "$errtmp"

  local was_exec=0
  [ -x "$src" ] && was_exec=1

  if ! mv "$tmp" "$dst"; then
    echo "render_file: failed to write $dst" >&2
    rm -f "$tmp"
    return 1
  fi
  [ "$was_exec" -eq 1 ] && chmod +x "$dst"
  return 0
}
