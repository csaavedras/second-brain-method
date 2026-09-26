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
# The "translatable set" (F3a — per-language .md overlay in lib/apply.sh)
# is: engine/claude/CLAUDE.md, engine/claude/commands/*.md,
# engine/claude/agents/*.md, engine/method/*.md. `.sh` files and
# settings.json are NEVER overlaid (see lib/apply.sh's header) so they are
# out of scope for checks 3-6 below.
#
# 3. Every translatable file has its pair under engine/i18n/<lang>/<same
#    relpath>, for every lang != en under engine/i18n/.
# 4. If the English file's first `method-version: X.Y` comment differs
#    from its i18n/<lang>/ pair's first `method-version: X.Y`, that's a
#    stale translation — fail naming lang + file.
# 5. The set of @@[A-Z0-9_]+@@ tokens (sorted, unique) must be identical
#    between the English file and its i18n/<lang>/ pair — a dropped/added
#    placeholder means the overlay would fail to render or silently lose a
#    substitution.
# 6. No orphans: every file under engine/i18n/<lang>/ other than
#    messages.env must mirror a file in the translatable set (relpath match)
#    — an i18n file with no English counterpart is never installed by
#    apply() and is dead weight/a typo.
#
# With only en/ present (today), checks 3-6 pass trivially — nothing to
# compare against yet.
#
# Usage: bash tests/check-i18n.sh [repo_root]
#   - repo_root: optional positional arg, defaults to the REPO_ROOT env var
#     if set, else this script's own repo checkout. Lets tests run these
#     checks against a throwaway repo copy (e.g. a synthetic i18n/<lang>/)
#     without touching the real engine/i18n/.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${1:-}" ]; then
  REPO_ROOT="$(cd "$1" && pwd)"
elif [ -n "${REPO_ROOT:-}" ]; then
  REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
else
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

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
# Build the translatable set: relpaths (under engine/) of every file an
# i18n/<lang>/ overlay may replace. Source of truth = the English tree.
# =============================================================================
TRANSLATABLE="$TDIR/translatable.txt"
: > "$TRANSLATABLE"
[ -f "$REPO_ROOT/engine/claude/CLAUDE.md" ] && printf 'claude/CLAUDE.md\n' >> "$TRANSLATABLE"
for f in "$REPO_ROOT"/engine/claude/commands/*.md; do
  [ -f "$f" ] || continue
  printf 'claude/commands/%s\n' "$(basename "$f")" >> "$TRANSLATABLE"
done
for f in "$REPO_ROOT"/engine/claude/agents/*.md; do
  [ -f "$f" ] || continue
  printf 'claude/agents/%s\n' "$(basename "$f")" >> "$TRANSLATABLE"
done
for f in "$REPO_ROOT"/engine/method/*.md; do
  [ -f "$f" ] || continue
  printf 'method/%s\n' "$(basename "$f")" >> "$TRANSLATABLE"
done
sort -u -o "$TRANSLATABLE" "$TRANSLATABLE"

# extract_method_version <file> — prints the X.Y from the FIRST
# `method-version: X.Y` occurrence in <file>, or nothing if none.
extract_method_version() {
  grep -oE 'method-version:[[:space:]]*[0-9]+\.[0-9]+' "$1" 2>/dev/null \
    | head -1 \
    | grep -oE '[0-9]+\.[0-9]+'
}

MISSING_PAIRS=""
STALE_VERSIONS=""
TOKEN_MISMATCHES=""
ORPHANS=""

for d in "$I18N_ROOT"/*/; do
  [ -d "$d" ] || continue
  lang="$(basename "$d")"
  [ "$lang" = "en" ] && continue

  # --- 3. every translatable file has its pair under i18n/<lang>/ --------
  while IFS= read -r relpath; do
    [ -n "$relpath" ] || continue
    if [ ! -f "$d$relpath" ]; then
      MISSING_PAIRS="$MISSING_PAIRS
  $lang: missing pair for $relpath"
      continue
    fi

    # --- 4. method-version parity (only meaningful when the pair exists) -
    en_version="$(extract_method_version "$REPO_ROOT/engine/$relpath")"
    lang_version="$(extract_method_version "$d$relpath")"
    if [ -n "$en_version" ] && [ "$en_version" != "$lang_version" ]; then
      STALE_VERSIONS="$STALE_VERSIONS
  $lang: $relpath has method-version [$lang_version], expected [$en_version]"
    fi

    # --- 5. @@TOKEN@@ set parity ------------------------------------------
    relpath_flat="$(printf '%s' "$relpath" | tr '/' '_')"
    en_tokens="$TDIR/en_tokens_${lang}_${relpath_flat}.txt"
    lang_tokens="$TDIR/lang_tokens_${lang}_${relpath_flat}.txt"
    grep -oE '@@[A-Z0-9_]+@@' "$REPO_ROOT/engine/$relpath" 2>/dev/null | sort -u > "$en_tokens"
    grep -oE '@@[A-Z0-9_]+@@' "$d$relpath" 2>/dev/null | sort -u > "$lang_tokens"
    if ! cmp -s "$en_tokens" "$lang_tokens"; then
      token_diff="$(comm -3 "$en_tokens" "$lang_tokens" | tr '\n' ' ')"
      TOKEN_MISMATCHES="$TOKEN_MISMATCHES
  $lang: $relpath token set differs (en-only/lang-only, tab-separated): [$token_diff]"
    fi
  done < "$TRANSLATABLE"

  # --- 6. no orphans: every i18n/<lang>/ file (except messages.env) mirrors
  #        a file in the translatable set --------------------------------
  while IFS= read -r found; do
    [ -n "$found" ] || continue
    relpath="${found#"$d"}"
    [ "$relpath" = "messages.env" ] && continue
    if ! grep -qxF "$relpath" "$TRANSLATABLE"; then
      ORPHANS="$ORPHANS
  $lang: orphan i18n file with no English counterpart: $relpath"
    fi
  done < <(find "$d" -type f 2>/dev/null | sort)
done

if [ -z "$MISSING_PAIRS" ]; then
  pass "3. every translatable file has its i18n/<lang>/ pair, for every lang != en"
else
  fail "3. missing i18n pair(s):$MISSING_PAIRS"
fi

if [ -z "$STALE_VERSIONS" ]; then
  pass "4. method-version comment matches between English files and their i18n/<lang>/ pair"
else
  fail "4. stale method-version in i18n pair(s):$STALE_VERSIONS"
fi

if [ -z "$TOKEN_MISMATCHES" ]; then
  pass "5. @@TOKEN@@ placeholder set is identical between English files and their i18n/<lang>/ pair"
else
  fail "5. @@TOKEN@@ set mismatch in i18n pair(s):$TOKEN_MISMATCHES"
fi

if [ -z "$ORPHANS" ]; then
  pass "6. no i18n/<lang>/ file lacks an English counterpart in the translatable set"
else
  fail "6. orphan i18n file(s):$ORPHANS"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
exit $?
