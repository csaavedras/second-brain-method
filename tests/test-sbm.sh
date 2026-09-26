#!/bin/bash
# tests/test-sbm.sh — behavioral tests for the `sbm` CLI (install/update/
# status) and the lib/apply.sh algorithm it drives. Plain bash, no
# framework, matching tests/test-render.sh's style. bash 3.2 safe (no
# associative arrays, no ${var//pat/rep}, no mapfile).
#
# Every scenario lives under one shared mktemp -d, in its own subdirectory.
# Every sbm/install.sh invocation below sets BOTH CLAUDE_HOME and HOME to
# paths under that temp dir — the real ~/.claude and real vault are never
# touched.
#
# Usage: bash tests/test-sbm.sh   (exit 0 = all pass)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SBM="$REPO_ROOT/sbm"

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

RSYNC_EXCLUDES="--exclude=.git --exclude=graphify-out --exclude=__pycache__ --exclude=.claude --exclude=CLAUDE.local.md"

# make_repo_copy <dest_dir> — rsync a clean copy of the real repo into
# <dest_dir> (excluding .git/graphify-out/__pycache__/.claude/
# CLAUDE.local.md — the last two are this live checkout's own local/
# untracked files, not part of the shipped product).
make_repo_copy() {
  local dest="$1"
  mkdir -p "$dest"
  # shellcheck disable=SC2086
  rsync -a $RSYNC_EXCLUDES "$REPO_ROOT/" "$dest/"
}

# =============================================================================
# Case 1 — fresh install, en
# =============================================================================
M="$TDIR/main"
MC="$M/c"
MH="$M/home"
MVAULT="$MH/second-brain"
mkdir -p "$MC" "$MH"

OUT1="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" install --yes 2>&1)"
RC1=$?

C1_OK=1
[ "$RC1" -eq 0 ] || { C1_OK=0; fail "1. fresh install exit 0 — rc=$RC1 out=[$OUT1]"; }
grep -qF '<!-- BEGIN SECOND BRAIN METHOD -->' "$MC/CLAUDE.md" 2>/dev/null || { C1_OK=0; fail "1. CLAUDE.md missing managed block"; }
[ -f "$MVAULT/method/BRAIN.md" ] || { C1_OK=0; fail "1. vault method/BRAIN.md missing"; }
[ -f "$MVAULT/method/scripts/brain-health.sh" ] || { C1_OK=0; fail "1. vault method/scripts/brain-health.sh missing"; }
[ -d "$MVAULT/.git" ] || { C1_OK=0; fail "1. vault .git missing"; }

CFG1_VERSION="$(jq -r '.version' "$MC/.second-brain/config.json" 2>/dev/null)"
CFG1_LANG="$(jq -r '.lang' "$MC/.second-brain/config.json" 2>/dev/null)"
REPO_VERSION="$(cat "$REPO_ROOT/VERSION")"
[ "$CFG1_VERSION" = "$REPO_VERSION" ] && [ "$CFG1_LANG" = "en" ] || { C1_OK=0; fail "1. config.json version/lang wrong — version=$CFG1_VERSION lang=$CFG1_LANG"; }

LEFTOVER1="$(grep -rlE '@@[A-Z_]+@@' "$MC" "$MVAULT" 2>/dev/null)"
[ -z "$LEFTOVER1" ] || { C1_OK=0; fail "1. leftover @@..@@ placeholders: $LEFTOVER1"; }

[ ! -d "$MVAULT/method/method" ] || { C1_OK=0; fail "1/5. nested vault/method/method exists"; }

[ "$C1_OK" -eq 1 ] && pass "1. fresh install en: exit 0, CLAUDE.md block, vault files, .git, config.json, no leftover placeholders, no nested method/method"

# 1b. fresh install --lang es (no engine/i18n/es/ yet) -> exit 1, names en available
T1B="$TDIR/case1b"
C1B="$T1B/c"
H1B="$T1B/home"
mkdir -p "$C1B" "$H1B"
OUT1B="$(CLAUDE_HOME="$C1B" HOME="$H1B" "$SBM" install --yes --lang es 2>&1)"
RC1B=$?
if [ "$RC1B" -ne 0 ] && printf '%s' "$OUT1B" | grep -q 'Available language(s): en' && ! printf '%s' "$OUT1B" | grep -qi 'no such file or directory'; then
  pass "1b. install --lang es (unavailable) -> exit 1, names en as available, not a raw file-not-found"
else
  fail "1b. install --lang es handling wrong — rc=$RC1B out=[$OUT1B]"
fi

# =============================================================================
# Case 2 — install repeated; then update --no-pull with no changes
# =============================================================================
CFG_SHA_BEFORE="$(shasum -a 256 "$MC/.second-brain/config.json" | cut -d' ' -f1)"
OUT2="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" install --yes 2>&1)"
RC2=$?
CFG_SHA_AFTER="$(shasum -a 256 "$MC/.second-brain/config.json" | cut -d' ' -f1)"

if [ "$RC2" -ne 0 ] && printf '%s' "$OUT2" | grep -qi 'already installed' && [ "$CFG_SHA_BEFORE" = "$CFG_SHA_AFTER" ]; then
  pass "2a. repeated install -> exit 1, 'already installed'/suggests update, config.json unchanged"
else
  fail "2a. repeated install handling wrong — rc=$RC2 out=[$OUT2] sha-before=$CFG_SHA_BEFORE sha-after=$CFG_SHA_AFTER"
fi

BACKUPS_BEFORE="$(find "$MC/.second-brain/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"
OUT2B="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC2B=$?
BACKUPS_AFTER="$(find "$MC/.second-brain/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"

if [ "$RC2B" -eq 0 ] && printf '%s' "$OUT2B" | grep -qE 'conflict=0 .*taken=0' && [ "$BACKUPS_BEFORE" = "$BACKUPS_AFTER" ]; then
  pass "2b. update --no-pull with no changes -> exit 0, conflict=0 taken=0, no new backup dir"
else
  fail "2b. no-op update handling wrong — rc=$RC2B out=[$OUT2B] backups-before=[$BACKUPS_BEFORE] backups-after=[$BACKUPS_AFTER]"
fi

# =============================================================================
# Case 3 — hand-edit + re-apply -> conflict -> .new -> status lists it ->
#          --take-new resolves
# =============================================================================
CLOSE_DEST="$MC/commands/close.md"
printf '\n<!-- hand-edited by test case 3 -->\n' >> "$CLOSE_DEST"
CLOSE_BEFORE="$(cat "$CLOSE_DEST")"

OUT3="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC3=$?
CLOSE_AFTER="$([ -f "$CLOSE_DEST" ] && cat "$CLOSE_DEST")"

C3_OK=1
[ "$RC3" -eq 0 ] || { C3_OK=0; fail "3. update after hand-edit exit != 0 — out=[$OUT3]"; }
printf '%s' "$OUT3" | grep -qE 'conflict=1 ' || { C3_OK=0; fail "3. summary doesn't show conflict=1 — out=[$OUT3]"; }
[ -f "$CLOSE_DEST.new" ] || { C3_OK=0; fail "3. commands/close.md.new not created"; }
[ "$CLOSE_BEFORE" = "$CLOSE_AFTER" ] || { C3_OK=0; fail "3. commands/close.md was modified, expected byte-unchanged"; }

[ "$C3_OK" -eq 1 ] && pass "3a. hand-edit + update --no-pull -> conflict=1, close.md.new written, close.md byte-unchanged"

OUT3S="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" status 2>&1)"
RC3S=$?
if [ "$RC3S" -eq 0 ] && printf '%s' "$OUT3S" | grep -qF "$CLOSE_DEST.new" && printf '%s' "$OUT3S" | grep -qF "     $CLOSE_DEST"; then
  pass "3b. status -> exit 0, lists commands/close.md under both .new and edited"
else
  fail "3b. status output wrong — rc=$RC3S out=[$OUT3S]"
fi

OUT3T="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull --take-new 2>&1)"
RC3T=$?
C3T_OK=1
[ "$RC3T" -eq 0 ] || { C3T_OK=0; fail "3c. update --take-new exit != 0 — out=[$OUT3T]"; }
[ ! -f "$CLOSE_DEST.new" ] || { C3T_OK=0; fail "3c. close.md.new still present after --take-new"; }
if [ -f "$CLOSE_DEST" ] && grep -qF 'hand-edited by test case 3' "$CLOSE_DEST"; then
  C3T_OK=0
  fail "3c. close.md still contains the hand edit after --take-new"
fi
BACKUP_CLOSE_FOUND="$(find "$MC/.second-brain/backups" -type f -path '*/commands/close.md' 2>/dev/null | head -1)"
[ -n "$BACKUP_CLOSE_FOUND" ] || { C3T_OK=0; fail "3c. no backup of hand-edited close.md found under .second-brain/backups/"; }

[ "$C3T_OK" -eq 1 ] && pass "3c. update --no-pull --take-new -> close.md.new gone, close.md matches fresh render, old content backed up"

# =============================================================================
# Case 4 — CLAUDE.md: user's own rules preserved across update; corrupt
#          markers abort cleanly
# =============================================================================
printf '\n## My own extra rule\nDo the thing.\n' >> "$MC/CLAUDE.md"

OUT4="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC4=$?
if [ "$RC4" -eq 0 ] && grep -qF '## My own extra rule' "$MC/CLAUDE.md" && grep -qF '<!-- BEGIN SECOND BRAIN METHOD -->' "$MC/CLAUDE.md"; then
  pass "4a. update --no-pull preserves user's own CLAUDE.md rules below the managed block"
else
  fail "4a. own-rule preservation broken — rc=$RC4 out=[$OUT4]"
fi

CLAUDE_MD_BEFORE_CORRUPT="$(cat "$MC/CLAUDE.md")"
# Corrupt: duplicate the BEGIN marker elsewhere in the file.
printf '\n<!-- BEGIN SECOND BRAIN METHOD -->\n' >> "$MC/CLAUDE.md"
CLAUDE_MD_CORRUPT_SNAPSHOT="$(cat "$MC/CLAUDE.md")"

BACKUPS_BEFORE4="$(find "$MC/.second-brain/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"
OUT4C="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC4C=$?
BACKUPS_AFTER4="$(find "$MC/.second-brain/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)"
CLAUDE_MD_AFTER_CORRUPT="$(cat "$MC/CLAUDE.md")"

C4C_OK=1
[ "$RC4C" -ne 0 ] || { C4C_OK=0; fail "4b. corrupt CLAUDE.md update didn't fail — out=[$OUT4C]"; }
printf '%s' "$OUT4C" | grep -qi 'corrupt' || { C4C_OK=0; fail "4b. error doesn't mention corrupt block — out=[$OUT4C]"; }
[ "$CLAUDE_MD_CORRUPT_SNAPSHOT" = "$CLAUDE_MD_AFTER_CORRUPT" ] || { C4C_OK=0; fail "4b. CLAUDE.md content changed despite abort"; }
[ "$BACKUPS_BEFORE4" = "$BACKUPS_AFTER4" ] || { C4C_OK=0; fail "4b. a new backup dir was created despite the abort"; }

[ "$C4C_OK" -eq 1 ] && pass "4b. corrupt CLAUDE.md markers -> update --no-pull aborts non-zero, file byte-identical, nothing else touched"

# Repair CLAUDE.md so later cases (5, 6) that touch MC continue from a sane
# state: drop the extra duplicated BEGIN line we injected above.
REPAIRED="$(printf '%s\n' "$CLAUDE_MD_BEFORE_CORRUPT")"
printf '%s' "$REPAIRED" > "$MC/CLAUDE.md"

# =============================================================================
# Case 5 — a file removed from the engine gets DELETED if untouched, or
#          ORPHANED if hand-edited; nested vault/method/method already
#          checked in case 1 above.
# =============================================================================
REPO_A="$TDIR/repo-copy-a"
make_repo_copy "$REPO_A"
rm -f "$REPO_A/engine/method/METRICS.md"

OUT5A="$(CLAUDE_HOME="$MC" HOME="$MH" "$REPO_A/sbm" update --no-pull 2>&1)"
RC5A=$?
if [ "$RC5A" -eq 0 ] && printf '%s' "$OUT5A" | grep -qE 'deleted=1' && [ ! -f "$MVAULT/method/METRICS.md" ]; then
  pass "5a. engine drops an untouched file -> update reports it deleted, file removed from vault"
else
  fail "5a. deleted-file handling wrong — rc=$RC5A out=[$OUT5A] exists=$([ -f "$MVAULT/method/METRICS.md" ] && echo yes || echo no)"
fi

REPO_B="$TDIR/repo-copy-b"
make_repo_copy "$REPO_B"
rm -f "$REPO_B/engine/method/MODEL-ROUTING.md"
printf '\n<!-- hand-edited before the removal update -->\n' >> "$MVAULT/method/MODEL-ROUTING.md"

OUT5B="$(CLAUDE_HOME="$MC" HOME="$MH" "$REPO_B/sbm" update --no-pull 2>&1)"
RC5B=$?
if [ "$RC5B" -eq 0 ] && printf '%s' "$OUT5B" | grep -qE 'orphaned=1' && [ -f "$MVAULT/method/MODEL-ROUTING.md" ] && grep -qF 'hand-edited before the removal update' "$MVAULT/method/MODEL-ROUTING.md"; then
  pass "5b. engine drops a hand-edited file -> update reports it orphaned, file kept with the user's edit intact"
else
  fail "5b. orphaned-file handling wrong — rc=$RC5B out=[$OUT5B]"
fi

# =============================================================================
# Case 6 — update --lang es (not available yet) -> exit 1, not a crash
# =============================================================================
OUT6="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull --lang es 2>&1)"
RC6=$?
if [ "$RC6" -eq 1 ] && printf '%s' "$OUT6" | grep -q 'Available language(s): en'; then
  pass "6. update --no-pull --lang es -> exit 1, same 'not available yet' message, not a crash"
else
  fail "6. update --lang es handling wrong — rc=$RC6 out=[$OUT6]"
fi

# =============================================================================
# Case 7 — user's own settings.json hook survives install AND update
# =============================================================================
T7="$TDIR/case7"
C7="$T7/c"
H7="$T7/home"
V7="$T7/vault7"
mkdir -p "$C7" "$H7"
cat > "$C7/settings.json" <<'EOF7'
{
  "myCustomTopLevelKey": "keep-me",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/bin/echo my-own-custom-hook" }
        ]
      }
    ]
  }
}
EOF7

OUT7I="$(CLAUDE_HOME="$C7" HOME="$H7" "$SBM" install --yes --vault "$V7" 2>&1)"
RC7I=$?
C7_OK=1
[ "$RC7I" -eq 0 ] || { C7_OK=0; fail "7. install with pre-seeded settings.json failed — out=[$OUT7I]"; }
jq -e '.myCustomTopLevelKey == "keep-me"' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. unrelated top-level key lost after install"; }
jq -e '[.hooks.Stop[].hooks[]?.command] | any(test("my-own-custom-hook"))' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. custom Stop hook lost after install"; }
jq -e '[.hooks.Stop[].hooks[]?.command] | any(test("check-close"))' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. method's own check-close hook missing after install"; }

OUT7U="$(CLAUDE_HOME="$C7" HOME="$H7" "$SBM" update --no-pull 2>&1)"
RC7U=$?
[ "$RC7U" -eq 0 ] || { C7_OK=0; fail "7. update after settings seed failed — out=[$OUT7U]"; }
jq -e '.myCustomTopLevelKey == "keep-me"' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. unrelated top-level key lost after update"; }
jq -e '[.hooks.Stop[].hooks[]?.command] | any(test("my-own-custom-hook"))' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. custom Stop hook lost after update"; }
jq -e '[.hooks.Stop[].hooks[]?.command] | any(test("check-close"))' "$C7/settings.json" >/dev/null 2>&1 || { C7_OK=0; fail "7. method's own check-close hook missing after update"; }

[ "$C7_OK" -eq 1 ] && pass "7. user's unrelated settings.json key + custom Stop hook survive install AND update; method's own hooks present"

# =============================================================================
# Case 8 — adoption of a foreign install + CLAUDE.md take-new regression test
# =============================================================================
T8="$TDIR/case8"
C8="$T8/c"
H8="$T8/home"
V8="$T8/vault8"
mkdir -p "$C8/commands" "$H8"
printf '# My old CLAUDE.md\nSome personal rule.\n' > "$C8/CLAUDE.md"
printf 'My own close.md content, nothing like the engine ships.\n' > "$C8/commands/close.md"

OUT8I="$(CLAUDE_HOME="$C8" HOME="$H8" "$SBM" install --yes --vault "$V8" 2>&1)"
RC8I=$?
C8_OK=1
[ "$RC8I" -eq 0 ] || { C8_OK=0; fail "8a. adopting foreign install failed — out=[$OUT8I]"; }
printf '%s' "$OUT8I" | grep -qE 'conflict=2 ' || { C8_OK=0; fail "8a. summary doesn't show conflict=2 — out=[$OUT8I]"; }
[ -f "$C8/CLAUDE.md.new" ] || { C8_OK=0; fail "8a. CLAUDE.md.new not created"; }
[ -f "$C8/commands/close.md.new" ] || { C8_OK=0; fail "8a. commands/close.md.new not created"; }
if [ "$(cat "$C8/CLAUDE.md")" != "$(printf '# My old CLAUDE.md\nSome personal rule.\n')" ]; then
  C8_OK=0; fail "8a. CLAUDE.md was modified, expected byte-unchanged"
fi
if [ "$(cat "$C8/commands/close.md")" != "$(printf 'My own close.md content, nothing like the engine ships.\n')" ]; then
  C8_OK=0; fail "8a. commands/close.md was modified, expected byte-unchanged"
fi

[ "$C8_OK" -eq 1 ] && pass "8a. adopting a foreign install: exit 0, 2 conflicts, .new files written, originals byte-unchanged"

OUT8T="$(CLAUDE_HOME="$C8" HOME="$H8" "$SBM" update --no-pull --take-new 2>&1)"
RC8T=$?
C8T_OK=1
[ "$RC8T" -eq 0 ] || { C8T_OK=0; fail "8b. update --take-new failed — out=[$OUT8T]"; }
[ ! -f "$C8/CLAUDE.md.new" ] || { C8T_OK=0; fail "8b. CLAUDE.md.new still present"; }
[ ! -f "$C8/commands/close.md.new" ] || { C8T_OK=0; fail "8b. commands/close.md.new still present"; }
BACKUP_CLAUDEMD_FOUND="$(find "$C8/.second-brain/backups" -type f -path '*/CLAUDE.md' 2>/dev/null | head -1)"
BACKUP_CLOSEMD_FOUND="$(find "$C8/.second-brain/backups" -type f -path '*/commands/close.md' 2>/dev/null | head -1)"
[ -n "$BACKUP_CLAUDEMD_FOUND" ] || { C8T_OK=0; fail "8b. no backup of the old CLAUDE.md found"; }
[ -n "$BACKUP_CLOSEMD_FOUND" ] || { C8T_OK=0; fail "8b. no backup of the old commands/close.md found"; }
grep -qF '<!-- BEGIN SECOND BRAIN METHOD -->' "$C8/CLAUDE.md" 2>/dev/null || { C8T_OK=0; fail "8b. CLAUDE.md missing the managed block after --take-new"; }
if grep -q 'My old CLAUDE.md\|Some personal rule' "$C8/CLAUDE.md" 2>/dev/null; then
  C8T_OK=0
  fail "8b. REGRESSION: CLAUDE.md still contains trace of the old foreign content after --take-new"
fi

[ "$C8T_OK" -eq 1 ] && pass "8b. update --take-new: .new files gone, backups exist, CLAUDE.md contains ONLY the managed block (regression test for the append-instead-of-replace bug)"

# =============================================================================
# Case 9 — update git-flow: dirty repo aborts, wrong branch aborts,
#          --no-pull bypasses, a real git pull --ff-only applies and
#          updates the reported version
# =============================================================================
T9="$TDIR/case9"
REPO9="$T9/repo"
make_repo_copy "$REPO9"
(
  cd "$REPO9" || exit 1
  git init -q -b main
  git add -A
  git commit -q -m 'throwaway repo for sbm update git-flow tests'
) >/dev/null 2>"$T9/repo-init.err"
if [ ! -d "$REPO9/.git" ]; then
  fail "9. setup — failed to init throwaway git repo: $(cat "$T9/repo-init.err")"
else
  C9="$T9/c"
  H9="$T9/home"
  V9="$T9/vault9"
  mkdir -p "$C9" "$H9"
  OUT9I="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" install --yes --vault "$V9" 2>&1)"
  RC9I=$?
  if [ "$RC9I" -ne 0 ]; then
    fail "9. setup — install against throwaway repo failed: $OUT9I"
  else
    CFG9_SHA_BEFORE_A="$(shasum -a 256 "$C9/.second-brain/config.json" | cut -d' ' -f1)"

    # (a) uncommitted change -> update (default, pull) aborts, mentions
    #     uncommitted changes; nothing else touched.
    : > "$REPO9/DIRTY_FILE.txt"
    OUT9A="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" update 2>&1)"
    RC9A=$?
    CFG9_SHA_AFTER_A="$(shasum -a 256 "$C9/.second-brain/config.json" | cut -d' ' -f1)"
    if [ "$RC9A" -ne 0 ] && printf '%s' "$OUT9A" | grep -qi 'uncommitted' && [ "$CFG9_SHA_BEFORE_A" = "$CFG9_SHA_AFTER_A" ]; then
      pass "9a. dirty throwaway repo -> update (pull enabled) aborts, mentions uncommitted changes, config untouched"
    else
      fail "9a. dirty-repo gate wrong — rc=$RC9A out=[$OUT9A]"
    fi
    rm -f "$REPO9/DIRTY_FILE.txt"

    # (b) wrong branch -> update aborts, names the branch.
    (cd "$REPO9" && git checkout -q -b feature-branch)
    OUT9B="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" update 2>&1)"
    RC9B=$?
    if [ "$RC9B" -ne 0 ] && printf '%s' "$OUT9B" | grep -qF "'feature-branch'"; then
      pass "9b. wrong branch (feature-branch) -> update aborts, message names the branch"
    else
      fail "9b. wrong-branch gate wrong — rc=$RC9B out=[$OUT9B]"
    fi
    (cd "$REPO9" && git checkout -q main && git branch -q -D feature-branch)

    # (c) --no-pull bypasses git entirely: succeeds even with dirty tree and
    #     wrong branch checked out.
    : > "$REPO9/DIRTY_FILE2.txt"
    (cd "$REPO9" && git checkout -q -b feature-branch-2)
    OUT9C="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" update --no-pull 2>&1)"
    RC9C=$?
    if [ "$RC9C" -eq 0 ]; then
      pass "9c. update --no-pull succeeds regardless of dirty tree / wrong branch (never touches git)"
    else
      fail "9c. update --no-pull unexpectedly failed — out=[$OUT9C]"
    fi
    (cd "$REPO9" && git checkout -q main && git branch -q -D feature-branch-2)
    rm -f "$REPO9/DIRTY_FILE2.txt"
    (cd "$REPO9" && git add -A && git commit -q -m 'cleanup after case 9c' --allow-empty) >/dev/null 2>&1

    # (d) clone BEFORE bumping VERSION in the original; point config's
    #     "repo" at the clone; bump the original; update (pull enabled) on
    #     the CLONE should pull the bump and report old->new version.
    REPO9_CLONE="$T9/repo-clone"
    if git clone -q "$REPO9" "$REPO9_CLONE" 2>"$T9/clone.err"; then
      NEW_VERSION="4.1.0-test-bump"
      printf '%s\n' "$NEW_VERSION" > "$REPO9/VERSION"
      (cd "$REPO9" && git add -A && git commit -q -m 'bump VERSION for test')

      jq --arg r "$REPO9_CLONE" '.repo = $r' "$C9/.second-brain/config.json" > "$T9/config.tmp" \
        && mv "$T9/config.tmp" "$C9/.second-brain/config.json"

      OUT9D="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9_CLONE/sbm" update 2>&1)"
      RC9D=$?
      CLONE_VERSION_AFTER="$(cat "$REPO9_CLONE/VERSION" 2>/dev/null)"
      D9_OK=1
      [ "$RC9D" -eq 0 ] || { D9_OK=0; fail "9d. update (pull enabled) on the clone failed — out=[$OUT9D]"; }
      printf '%s' "$OUT9D" | grep -qF "$REPO_VERSION" || { D9_OK=0; fail "9d. output doesn't show the old version ($REPO_VERSION)"; }
      printf '%s' "$OUT9D" | grep -qF "$NEW_VERSION" || { D9_OK=0; fail "9d. output doesn't show the new version ($NEW_VERSION)"; }
      [ "$CLONE_VERSION_AFTER" = "$NEW_VERSION" ] || { D9_OK=0; fail "9d. clone's VERSION file not updated by git pull — got [$CLONE_VERSION_AFTER]"; }

      OUT9S="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9_CLONE/sbm" status 2>&1)"
      RC9S=$?
      [ "$RC9S" -eq 0 ] || { D9_OK=0; fail "9d. status after pull-update failed"; }
      printf '%s' "$OUT9S" | grep -qF "$NEW_VERSION" || { D9_OK=0; fail "9d. status doesn't report the new version"; }
      if printf '%s' "$OUT9S" | grep -qi 'mismatch'; then
        D9_OK=0
        fail "9d. status still reports a version mismatch after the pull-update"
      fi

      [ "$D9_OK" -eq 1 ] && pass "9d. real git pull --ff-only applies a VERSION bump; update reports old->new; status shows the new version with no mismatch"
    else
      fail "9d. setup — git clone of the throwaway repo failed: $(cat "$T9/clone.err")"
    fi
  fi
fi

# =============================================================================
# Case 10 — syntax + i18n
# =============================================================================
SYNTAX10_FAILS=""
for f in "$SBM" "$REPO_ROOT/lib/apply.sh" "$REPO_ROOT/lib/settings-merge.sh"; do
  if ! bash -n "$f" 2>"$TDIR/err10-$(basename "$f")"; then
    SYNTAX10_FAILS="$SYNTAX10_FAILS $f($(cat "$TDIR/err10-$(basename "$f")"))"
  fi
done
if [ -z "$SYNTAX10_FAILS" ]; then
  pass "10a. bash -n passes on sbm, lib/apply.sh, lib/settings-merge.sh"
else
  fail "10a. bash -n failures:$SYNTAX10_FAILS"
fi

if bash "$SCRIPT_DIR/check-i18n.sh" >"$TDIR/i18n_out.txt" 2>&1; then
  pass "10b. tests/check-i18n.sh (invoked as a sub-check) passes"
else
  fail "10b. tests/check-i18n.sh failed:$(cat "$TDIR/i18n_out.txt")"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
exit $?
