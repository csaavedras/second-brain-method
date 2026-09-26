#!/bin/bash
# tests/test-render.sh — behavioral tests for lib/render.sh and the i18n
# placeholder layout (@@MSG_*@@ / @@VAULT@@). Plain bash, no framework.
# bash 3.2 safe (no associative arrays, no ${var//pat/rep}, no mapfile).
#
# Usage: bash tests/test-render.sh   (exit 0 = all pass)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/render.sh
. "$REPO_ROOT/lib/render.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $1"
}

# One shared scratch dir for the whole run; never touches real HOME/~/.claude.
TDIR="$(mktemp -d)" || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$TDIR"' EXIT

# =============================================================================
# 1. Behavioral escaping of MSG values
# =============================================================================
MENV1="$TDIR/messages1.env"
cat > "$MENV1" <<'EOF'
MSG_T=quo'te dq"uote home$HOME/x tick`y back\z amp&ersand hash#tag pct%%end
MSG_S=Value: %s end
EOF

SRC1="$TDIR/src1.sh"
cat > "$SRC1" <<'EOF'
#!/bin/bash
printf '@@MSG_T@@\n'
EOF

DST1="$TDIR/out1.sh"
if render_file "$SRC1" "$DST1" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err1"; then
  # Written to a file (not via "$(cat <<'EOF' ...)") because a heredoc body
  # with unbalanced quotes/backticks nested inside $(...) confuses bash's
  # own parser (a real bash quirk, unrelated to render_file).
  cat > "$TDIR/expected1.txt" <<'EOF'
quo'te dq"uote home$HOME/x tick`y back\z amp&ersand hash#tag pct%end
EOF
  EXPECTED1="$(cat "$TDIR/expected1.txt")"
  ACTUAL1="$(bash "$DST1" 2>&1)"
  if [ "$ACTUAL1" = "$EXPECTED1" ]; then
    pass "1. MSG value with quotes/\$HOME/backtick/backslash/&/#/%% renders and executes literally"
  else
    fail "1. MSG escaping mismatch — expected [$EXPECTED1] got [$ACTUAL1]"
  fi
else
  fail "1. render_file failed unexpectedly: $(cat "$TDIR/err1")"
fi

# =============================================================================
# 2. %s argument
# =============================================================================
SRC2="$TDIR/src2.sh"
cat > "$SRC2" <<'EOF'
#!/bin/bash
printf '@@MSG_S@@\n' "$1"
EOF

DST2="$TDIR/out2.sh"
if render_file "$SRC2" "$DST2" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err2"; then
  ACTUAL2="$(bash "$DST2" 'arg-with-%s-and-\n-literal' 2>&1)"
  EXPECTED2='Value: arg-with-%s-and-\n-literal end'
  if [ "$ACTUAL2" = "$EXPECTED2" ]; then
    pass "2. runtime %s argument containing %s and literal \\n is printed verbatim"
  else
    fail "2. %s argument mismatch — expected [$EXPECTED2] got [$ACTUAL2]"
  fi
else
  fail "2. render_file failed unexpectedly: $(cat "$TDIR/err2")"
fi

# =============================================================================
# 3. VAULT in .sh
# =============================================================================
SRC3="$TDIR/src3.sh"
cat > "$SRC3" <<'EOF'
#!/bin/bash
VAULT="${1:-@@VAULT@@}"
printf '%s\n' "$VAULT"
EOF

# 3a. $HOME/-prefixed vault_shell: prefix stays unescaped (expands at runtime).
DST3A="$TDIR/out3a.sh"
if render_file "$SRC3" "$DST3A" "$MENV1" "irrelevant" '$HOME/a & #b' 2>"$TDIR/err3a"; then
  CUSTOM_HOME="$TDIR/customhome"
  mkdir -p "$CUSTOM_HOME"
  ACTUAL3A="$(HOME="$CUSTOM_HOME" bash "$DST3A" 2>&1)"
  EXPECTED3A="$CUSTOM_HOME/a & #b"
  if [ "$ACTUAL3A" = "$EXPECTED3A" ]; then
    pass "3a. \$HOME/-prefixed VAULT in .sh expands \$HOME at runtime, rest literal"
  else
    fail "3a. VAULT \$HOME-prefix mismatch — expected [$EXPECTED3A] got [$ACTUAL3A]"
  fi
else
  fail "3a. render_file failed unexpectedly: $(cat "$TDIR/err3a")"
fi

# 3b. hostile absolute path vault_shell (not $HOME/-prefixed): fully escaped.
HOSTILE_VAULT='/tmp/v & #x \ '"'"'q'"'"' "dq" `tick`'
DST3B="$TDIR/out3b.sh"
if render_file "$SRC3" "$DST3B" "$MENV1" "irrelevant" "$HOSTILE_VAULT" 2>"$TDIR/err3b"; then
  ACTUAL3B="$(bash "$DST3B" 2>&1)"
  if [ "$ACTUAL3B" = "$HOSTILE_VAULT" ]; then
    pass "3b. hostile absolute-path VAULT in .sh executes to exactly the same path"
  else
    fail "3b. hostile VAULT mismatch — expected [$HOSTILE_VAULT] got [$ACTUAL3B]"
  fi
else
  fail "3b. render_file failed unexpectedly: $(cat "$TDIR/err3b")"
fi

# =============================================================================
# 4. VAULT in .md — literal, byte-compared
# =============================================================================
SRC4="$TDIR/src4.md"
cat > "$SRC4" <<'EOF'
Vault: @@VAULT@@
EOF

DST4="$TDIR/out4.md"
if render_file "$SRC4" "$DST4" "$MENV1" "$HOSTILE_VAULT" 'irrelevant' 2>"$TDIR/err4"; then
  EXPECTED4_FILE="$TDIR/expected4.md"
  printf 'Vault: %s\n' "$HOSTILE_VAULT" > "$EXPECTED4_FILE"
  if cmp -s "$DST4" "$EXPECTED4_FILE"; then
    pass "4. VAULT in .md rendered literally (byte-identical to expected)"
  else
    fail "4. VAULT .md byte mismatch — $(diff "$EXPECTED4_FILE" "$DST4")"
  fi
else
  fail "4. render_file failed unexpectedly: $(cat "$TDIR/err4")"
fi

# =============================================================================
# 5. Missing MSG key
# =============================================================================
SRC5="$TDIR/src5.sh"
cat > "$SRC5" <<'EOF'
#!/bin/bash
printf '@@MSG_NOPE@@\n'
EOF

# 5a. dst pre-exists with sentinel content -> must be left untouched.
DST5A="$TDIR/out5a.sh"
printf 'sentinel content, do not touch\n' > "$DST5A"
cp "$DST5A" "$TDIR/out5a.sh.bak"
render_file "$SRC5" "$DST5A" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err5a"
RC5A=$?
if [ "$RC5A" -ne 0 ] && grep -q 'MSG_NOPE' "$TDIR/err5a" && cmp -s "$DST5A" "$TDIR/out5a.sh.bak"; then
  pass "5a. missing MSG_NOPE key -> non-zero, stderr mentions it, existing dst unchanged"
else
  fail "5a. missing-key handling wrong — rc=$RC5A stderr=[$(cat "$TDIR/err5a")] dst-changed=$([ ! -e "$TDIR/out5a.sh.bak" ] || cmp -s "$DST5A" "$TDIR/out5a.sh.bak"; echo $?)"
fi

# 5b. dst does not exist prior -> must not be created.
DST5B="$TDIR/out5b-does-not-exist.sh"
render_file "$SRC5" "$DST5B" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err5b"
RC5B=$?
if [ "$RC5B" -ne 0 ] && [ ! -e "$DST5B" ]; then
  pass "5b. missing MSG key with non-existing dst -> dst not created"
else
  fail "5b. expected non-zero rc and no dst created, got rc=$RC5B exists=$([ -e "$DST5B" ] && echo yes || echo no)"
fi

# =============================================================================
# 6. Leftover placeholder (not MSG_*/VAULT)
# =============================================================================
SRC6="$TDIR/src6.sh"
cat > "$SRC6" <<'EOF'
#!/bin/bash
echo '@@FOO_BAR@@'
EOF

DST6="$TDIR/out6.sh"
printf 'sentinel6\n' > "$DST6"
cp "$DST6" "$TDIR/out6.sh.bak"
render_file "$SRC6" "$DST6" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err6"
RC6=$?
if [ "$RC6" -ne 0 ] && cmp -s "$DST6" "$TDIR/out6.sh.bak"; then
  pass "6. leftover @@FOO_BAR@@ placeholder -> non-zero exit, dst untouched"
else
  fail "6. leftover-placeholder handling wrong — rc=$RC6"
fi

# =============================================================================
# 7. In-place render preserves the +x bit; non-executable src stays non-exec
# =============================================================================
SRC7A="$TDIR/inplace-exec.sh"
cat > "$SRC7A" <<'EOF'
#!/bin/bash
echo hi
EOF
chmod +x "$SRC7A"
render_file "$SRC7A" "$SRC7A" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err7a"
RC7A=$?
if [ "$RC7A" -eq 0 ] && [ -x "$SRC7A" ]; then
  pass "7a. in-place render on an executable file preserves the +x bit"
else
  fail "7a. +x bit lost after in-place render (rc=$RC7A)"
fi

SRC7B="$TDIR/inplace-noexec.sh"
cat > "$SRC7B" <<'EOF'
#!/bin/bash
echo hi
EOF
chmod -x "$SRC7B"
render_file "$SRC7B" "$SRC7B" "$MENV1" "~/vault" '$HOME/vault' 2>"$TDIR/err7b"
RC7B=$?
if [ "$RC7B" -eq 0 ] && [ ! -x "$SRC7B" ]; then
  pass "7b. in-place render on a non-executable file leaves it non-executable"
else
  fail "7b. non-executable src became executable (or render failed) rc=$RC7B"
fi

# =============================================================================
# 8. Every @@MSG_*@@ placeholder used in engine/**/*.sh has a key, and every
#    MSG_* key defined in messages.env is used somewhere (no dead keys).
# =============================================================================
REAL_MENV="$REPO_ROOT/engine/i18n/en/messages.env"
USED_KEYS="$TDIR/used_keys.txt"
DEFINED_KEYS="$TDIR/defined_keys.txt"
find "$REPO_ROOT/engine" -type f -name '*.sh' -print0 2>/dev/null \
  | xargs -0 grep -ohE '@@MSG_[A-Z0-9_]+@@' 2>/dev/null \
  | sed 's/@@//g' | sort -u > "$USED_KEYS"
grep -oE '^MSG_[A-Z0-9_]+' "$REAL_MENV" | sort -u > "$DEFINED_KEYS"

MISSING_KEYS="$(comm -23 "$USED_KEYS" "$DEFINED_KEYS")"
DEAD_KEYS="$(comm -13 "$USED_KEYS" "$DEFINED_KEYS")"

if [ -z "$MISSING_KEYS" ] && [ -z "$DEAD_KEYS" ]; then
  pass "8. every @@MSG_*@@ used in engine/**/*.sh has a key, no dead keys in messages.env"
else
  fail "8. placeholder/key mismatch — used-without-key: [$MISSING_KEYS] dead-keys: [$DEAD_KEYS]"
fi

# =============================================================================
# 9. Every engine .sh renders cleanly with the real messages.env, and the
#    rendered copy passes bash -n.
# =============================================================================
ENGINE_SH_FAILS=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  dst9="$TDIR/render9-$(basename "$f").out"
  if ! render_file "$f" "$dst9" "$REAL_MENV" "~/second-brain" '$HOME/second-brain' 2>"$TDIR/err9"; then
    ENGINE_SH_FAILS="$ENGINE_SH_FAILS render:$f($(cat "$TDIR/err9"))"
    continue
  fi
  if ! bash -n "$dst9" 2>"$TDIR/err9n"; then
    ENGINE_SH_FAILS="$ENGINE_SH_FAILS bash-n:$f($(cat "$TDIR/err9n"))"
  fi
done <<EOF9
$(find "$REPO_ROOT/engine" -type f -name '*.sh')
EOF9

if [ -z "$ENGINE_SH_FAILS" ]; then
  pass "9. every engine/**/*.sh renders cleanly with real messages.env and passes bash -n"
else
  fail "9. engine .sh render/bash-n failures:$ENGINE_SH_FAILS"
fi

# =============================================================================
# 10. Hook twins byte-identical: engine/claude/hooks/X.sh == engine/method/scripts/X.sh
# =============================================================================
TWIN_FAILS=""
while IFS= read -r hookf; do
  [ -n "$hookf" ] || continue
  bn="$(basename "$hookf")"
  twin="$REPO_ROOT/engine/method/scripts/$bn"
  if [ ! -f "$twin" ]; then
    TWIN_FAILS="$TWIN_FAILS missing-twin:$bn"
  elif ! cmp -s "$hookf" "$twin"; then
    TWIN_FAILS="$TWIN_FAILS differs:$bn"
  fi
done <<EOF10
$(find "$REPO_ROOT/engine/claude/hooks" -type f -name '*.sh')
EOF10

if [ -z "$TWIN_FAILS" ]; then
  pass "10. every engine/claude/hooks/*.sh is byte-identical to its engine/method/scripts twin"
else
  fail "10. hook-twin mismatches:$TWIN_FAILS"
fi

# =============================================================================
# 11. bash -n on every *.sh in the repo (excluding graphify-out/ and .git/)
# =============================================================================
SYNTAX_FAILS=""
while IFS= read -r shf; do
  [ -n "$shf" ] || continue
  if ! bash -n "$shf" 2>"$TDIR/err11"; then
    SYNTAX_FAILS="$SYNTAX_FAILS $shf($(cat "$TDIR/err11"))"
  fi
done <<EOF11
$(find "$REPO_ROOT" \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/graphify-out" \) -prune -o -type f -name '*.sh' -print)
EOF11

if [ -z "$SYNTAX_FAILS" ]; then
  pass "11. bash -n passes on every *.sh in the repo (excluding graphify-out/, .git/)"
else
  fail "11. bash -n failures:$SYNTAX_FAILS"
fi

# =============================================================================
# 12. Install smoke test
# =============================================================================
IT="$TDIR/install-smoke"
mkdir -p "$IT/c" "$IT/home"
cat > "$TDIR/vault_suffix.txt" <<'EOF12'
/v & #x \ 'q'
EOF12
VAULT_SUFFIX="$(cat "$TDIR/vault_suffix.txt")"
VAULT_ARG="$IT$VAULT_SUFFIX"

INSTALL_OUT="$TDIR/install_out.txt"
(
  cd "$REPO_ROOT" || exit 1
  CLAUDE_HOME="$IT/c" HOME="$IT/home" ./install.sh "$VAULT_ARG"
) >"$INSTALL_OUT" 2>&1
RC12=$?

LEFTOVER=""
if [ "$RC12" -eq 0 ]; then
  if grep -rlE '@@[A-Z_]+@@' "$IT/c" "$VAULT_ARG/method/scripts" >"$TDIR/leftover.txt" 2>/dev/null; then
    LEFTOVER="$(cat "$TDIR/leftover.txt")"
  fi
fi

if [ "$RC12" -eq 0 ] && grep -qF 'ok —' "$INSTALL_OUT" && [ -z "$LEFTOVER" ]; then
  pass "12. install.sh smoke test with hostile vault path: exit 0, 'ok —', no leftover placeholders"
else
  fail "12. install smoke failed — rc=$RC12 leftover=[$LEFTOVER] output_tail=[$(tail -5 "$INSTALL_OUT")]"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
exit $?
