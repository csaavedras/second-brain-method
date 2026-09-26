#!/bin/bash
# brain-health — vault health check (0 LLM tokens).
# Checks: frontmatter, broken wikilinks, orphan notes, long CONTEXT.md files,
# and possible secrets (the vault is synced: never credential values).
# Usage: brain-health.sh [vault-path]
set -u
VAULT="${1:-@@VAULT@@}"
[ -d "$VAULT" ] || { printf '@@MSG_HEALTH_ERR_NO_VAULT@@\n' "$VAULT"; exit 2; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# method/ (the method lives in the vault but is not part of the note graph)
# and .obsidian/.trash are excluded from the check.
find "$VAULT" -name '*.md' -type f \
  -not -path "$VAULT/method/*" \
  -not -path "$VAULT/.obsidian/*" \
  -not -path "$VAULT/.trash/*" | sort > "$TMP/files"
sed -E 's|.*/||; s|\.md$||' "$TMP/files" | sort -u > "$TMP/basenames"
TOTAL=$(wc -l < "$TMP/files" | tr -d ' ')

printf '@@MSG_HEALTH_HEADER@@\n' "$VAULT"
printf '@@MSG_HEALTH_NOTES@@\n' "$TOTAL"

# ── 1. Frontmatter: leading --- + type: + date: ────────────────────────────
: > "$TMP/fm"
while IFS= read -r f; do
  rel="${f#"$VAULT"/}"
  if ! head -1 "$f" | grep -q '^---$'; then
    printf '@@MSG_HEALTH_NO_FM@@\n' "$rel" >> "$TMP/fm"
    continue
  fi
  FM=$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")
  printf '%s\n' "$FM" | grep -q '^type:' || printf '@@MSG_HEALTH_NO_TYPE@@\n' "$rel" >> "$TMP/fm"
  printf '%s\n' "$FM" | grep -q '^date:' || printf '@@MSG_HEALTH_NO_DATE@@\n' "$rel" >> "$TMP/fm"
done < "$TMP/files"

# ── 2. Broken wikilinks: [[target]] with no target.md note in the vault ─────
: > "$TMP/broken"
: > "$TMP/targets"
while IFS= read -r f; do
  rel="${f#"$VAULT"/}"
  grep -oE '\[\[[^]|#]+' "$f" 2>/dev/null | sed -E 's|^\[\[||; s|.*/||; s|[[:space:]]+$||' | sort -u | \
  while IFS= read -r target; do
    [ -z "$target" ] && continue
    echo "$target" >> "$TMP/targets"
    grep -qxF "$target" "$TMP/basenames" || printf '@@MSG_HEALTH_BROKEN_LINK@@\n' "$target" "$rel" >> "$TMP/broken"
  done
done < "$TMP/files"
sort -u "$TMP/targets" -o "$TMP/targets"

# ── 3. Orphans: no incoming wikilink ─────────────────────────────────────────
# Structural files are excluded (they are not nodes of the knowledge graph).
: > "$TMP/orphans"
while IFS= read -r f; do
  rel="${f#"$VAULT"/}"
  case "$rel" in
    */plans/*|*/sessions/*|*/graph/*|briefs/*) continue ;;
  esac
  base=$(basename "$f" .md)
  case "$base" in
    home|hub|CONTEXT|README) continue ;;
  esac
  grep -qxF "$base" "$TMP/targets" || printf '@@MSG_HEALTH_ORPHAN@@\n' "$rel" >> "$TMP/orphans"
done < "$TMP/files"

# ── 4. CONTEXT.md over ~150 lines → archive to sessions/ ────────────────────
: > "$TMP/long"
while IFS= read -r f; do
  L=$(wc -l < "$f" | tr -d ' ')
  [ "$L" -gt 150 ] && printf '@@MSG_HEALTH_LONG_CONTEXT@@\n' "$L" "${f#"$VAULT"/}" >> "$TMP/long"
done < <(grep '/CONTEXT\.md$' "$TMP/files")

# ── 5. Possible secrets (only file:line, never the content) ──────────────────
: > "$TMP/secrets"
grep -rniE 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9\-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|secret|token|password)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9_\-]{16,}' \
  --include='*.md' -l "$VAULT" 2>/dev/null | while IFS= read -r f; do
    printf '@@MSG_HEALTH_SECRET@@\n' "${f#"$VAULT"/}" >> "$TMP/secrets"
done

# ── Report ───────────────────────────────────────────────────────────────────
ISSUES=0
report() {  # $1=title $2=file
  local n; n=$(wc -l < "$2" | tr -d ' ')
  if [ "$n" -gt 0 ]; then
    echo; echo "── $1: $n"
    cat "$2"
    ISSUES=$((ISSUES + n))
  else
    echo "── $1: ✓"
  fi
}
echo
report "$(printf '@@MSG_HEALTH_TITLE_FM@@')" "$TMP/fm"
report "$(printf '@@MSG_HEALTH_TITLE_BROKEN@@')" "$TMP/broken"
report "$(printf '@@MSG_HEALTH_TITLE_ORPHANS@@')" "$TMP/orphans"
report "$(printf '@@MSG_HEALTH_TITLE_LONG@@')" "$TMP/long"
report "$(printf '@@MSG_HEALTH_TITLE_SECRETS@@')" "$TMP/secrets"

echo
if [ "$ISSUES" -eq 0 ]; then
  printf '@@MSG_HEALTH_OK@@\n' "$TOTAL"
  exit 0
else
  printf '@@MSG_HEALTH_ISSUES@@\n' "$ISSUES"
  exit 1
fi
