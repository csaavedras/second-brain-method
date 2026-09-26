#!/bin/bash
# tests/check-i18n.sh — i18n parity checks, standalone and reusable.
# Plain bash, no framework. bash 3.2 safe (no associative arrays, no
# ${var//pat/rep}, no mapfile).
#
# 1. Every engine/i18n/*/messages.env directory has EXACTLY the same MSG_*
#    key set as engine/i18n/en/messages.env (the source of truth). With
#    only en/ present (today), this passes trivially — nothing to compare
#    against yet; that's correct, not a bug.
# 2. Every @@MSG_[A-Z0-9_]+@@ used anywhere under engine/**/*.sh, and every
#    bare MSG_SBM_[A-Z0-9_]+ referenced in ./sbm, has a corresponding key in
#    en/messages.env, with no dead (unused) keys.
#
# Usage: bash tests/check-i18n.sh   (exit 0 = all pass)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

TDIR="$(mktemp -d)" || { echo "FAIL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$TDIR"' EXIT

I18N_ROOT="$REPO_ROOT/engine/i18n"
SOURCE_MENV="$I18N_ROOT/en/messages.env"

if [ ! -f "$SOURCE_MENV" ]; then
  fail "setup — source of truth $SOURCE_MENV not found"
  echo ""
  echo "$PASS_COUNT passed, $FAIL_COUNT failed"
  exit 1
fi

SOURCE_KEYS="$TDIR/en_keys.txt"
grep -oE '^MSG_[A-Z0-9_]+' "$SOURCE_MENV" | sort -u > "$SOURCE_KEYS"

# =============================================================================
# 1. Key-set parity across engine/i18n/*/messages.env (vs en/, the source of
#    truth). Only en/ exists today -> trivially passes, nothing to compare.
# =============================================================================
PARITY_FAILS=""
for d in "$I18N_ROOT"/*/; do
  [ -d "$d" ] || continue
  lang="$(basename "$d")"
  [ "$lang" = "en" ] && continue
  menv="$d/messages.env"
  [ -f "$menv" ] || continue

  lang_keys="$TDIR/${lang}_keys.txt"
  grep -oE '^MSG_[A-Z0-9_]+' "$menv" | sort -u > "$lang_keys"

  missing_in_lang="$(comm -23 "$SOURCE_KEYS" "$lang_keys")"
  extra_in_lang="$(comm -13 "$SOURCE_KEYS" "$lang_keys")"

  if [ -n "$missing_in_lang" ] || [ -n "$extra_in_lang" ]; then
    PARITY_FAILS="$PARITY_FAILS
  $lang: missing-from-$lang=[$missing_in_lang] extra-in-$lang-not-in-en=[$extra_in_lang]"
  fi
done

if [ -z "$PARITY_FAILS" ]; then
  pass "1. every engine/i18n/*/messages.env has exactly the same MSG_* key set as en/ (source of truth)"
else
  fail "1. i18n key-set parity mismatch:$PARITY_FAILS"
fi

# =============================================================================
# 2. Every @@MSG_*@@ used in engine/**/*.sh, and every bare MSG_SBM_* used in
#    ./sbm, has a key in en/messages.env; no dead (unused) keys.
# =============================================================================
USED_KEYS="$TDIR/used_keys.txt"
find "$REPO_ROOT/engine" -type f -name '*.sh' -print0 2>/dev/null \
  | xargs -0 grep -ohE '@@MSG_[A-Z0-9_]+@@' 2>/dev/null \
  | sed 's/@@//g' > "$USED_KEYS"
grep -ohE 'MSG_SBM_[A-Z0-9_]+' "$REPO_ROOT/sbm" 2>/dev/null >> "$USED_KEYS"
sort -u -o "$USED_KEYS" "$USED_KEYS"

MISSING_KEYS="$(comm -23 "$USED_KEYS" "$SOURCE_KEYS")"
DEAD_KEYS="$(comm -13 "$USED_KEYS" "$SOURCE_KEYS")"

if [ -z "$MISSING_KEYS" ] && [ -z "$DEAD_KEYS" ]; then
  pass "2. every @@MSG_*@@ used in engine/**/*.sh and every bare MSG_SBM_* used in sbm has a key, no dead keys in en/messages.env"
else
  fail "2. placeholder/key mismatch — used-without-key: [$MISSING_KEYS] dead-keys: [$DEAD_KEYS]"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
exit $?
