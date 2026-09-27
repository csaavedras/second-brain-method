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

HOME1_MD="$MVAULT/00-index/home.md"
TODAY1="$(date +%Y-%m-%d)"
[ -f "$HOME1_MD" ] || { C1_OK=0; fail "1. vault 00-index/home.md missing"; }
grep -qF 'type: moc' "$HOME1_MD" 2>/dev/null || { C1_OK=0; fail "1. home.md missing 'type: moc'"; }
grep -qF "date: $TODAY1" "$HOME1_MD" 2>/dev/null || { C1_OK=0; fail "1. home.md missing today's date: line"; }
grep -qF '# Home — second brain' "$HOME1_MD" 2>/dev/null || { C1_OK=0; fail "1. home.md missing '# Home — second brain' heading"; }

CFG1_VERSION="$(jq -r '.version' "$MC/.second-brain/config.json" 2>/dev/null)"
CFG1_LANG="$(jq -r '.lang' "$MC/.second-brain/config.json" 2>/dev/null)"
REPO_VERSION="$(cat "$REPO_ROOT/VERSION")"
[ "$CFG1_VERSION" = "$REPO_VERSION" ] && [ "$CFG1_LANG" = "en" ] || { C1_OK=0; fail "1. config.json version/lang wrong — version=$CFG1_VERSION lang=$CFG1_LANG"; }

LEFTOVER1="$(grep -rlE '@@[A-Z_]+@@' "$MC" "$MVAULT" 2>/dev/null)"
[ -z "$LEFTOVER1" ] || { C1_OK=0; fail "1. leftover @@..@@ placeholders: $LEFTOVER1"; }

[ ! -d "$MVAULT/method/method" ] || { C1_OK=0; fail "1/5. nested vault/method/method exists"; }

[ "$C1_OK" -eq 1 ] && pass "1. fresh install en: exit 0, CLAUDE.md block, vault files, .git, config.json, no leftover placeholders, no nested method/method"

# 1b. fresh install --lang zz (never shipped, a non-existent language by
#     construction, unlike "es" which may land for real later) -> exit 1,
#     names en available
T1B="$TDIR/case1b"
C1B="$T1B/c"
H1B="$T1B/home"
mkdir -p "$C1B" "$H1B"
OUT1B="$(CLAUDE_HOME="$C1B" HOME="$H1B" "$SBM" install --yes --lang zz 2>&1)"
RC1B=$?
if [ "$RC1B" -ne 0 ] && printf '%s' "$OUT1B" | grep -q 'Available language(s): en' && ! printf '%s' "$OUT1B" | grep -qi 'no such file or directory'; then
  pass "1b. install --lang zz (unavailable) -> exit 1, names en as available, not a raw file-not-found"
else
  fail "1b. install --lang zz handling wrong — rc=$RC1B out=[$OUT1B]"
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
# Case 6 — update --lang zz (non-existent language) -> exit 1, not a crash
# =============================================================================
OUT6="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull --lang zz 2>&1)"
RC6=$?
if [ "$RC6" -eq 1 ] && printf '%s' "$OUT6" | grep -q 'Available language(s): en'; then
  pass "6. update --no-pull --lang zz -> exit 1, same 'not available yet' message, not a crash"
else
  fail "6. update --lang zz handling wrong — rc=$RC6 out=[$OUT6]"
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
BLOCK_COUNT8="$(grep -cF '<!-- BEGIN SECOND BRAIN METHOD -->' "$C8/CLAUDE.md" 2>/dev/null || true)"
[ "$BLOCK_COUNT8" -eq 1 ] || { C8T_OK=0; fail "8b. CLAUDE.md BEGIN marker count != 1 — got $BLOCK_COUNT8"; }
# F7: --take-new on a marker-less CLAUDE.md backs up the old file (checked
# above) then APPENDS the block onto it — the user's old foreign content is
# kept, not discarded (this replaces the old "CLAUDE.md contains ONLY the
# managed block" expectation, which was the append-instead-of-replace bug
# in the other direction: it used to discard the user's own rules).
if ! grep -q 'My old CLAUDE.md' "$C8/CLAUDE.md" 2>/dev/null || ! grep -q 'Some personal rule' "$C8/CLAUDE.md" 2>/dev/null; then
  C8T_OK=0
  fail "8b. REGRESSION: CLAUDE.md lost the user's old foreign content after --take-new (F7)"
fi

[ "$C8T_OK" -eq 1 ] && pass "8b. update --take-new: .new files gone, backups exist, CLAUDE.md keeps the old foreign content with the managed block appended once (F7 regression test)"

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

    # (a) uncommitted change to a TRACKED file -> update (default, pull)
    #     aborts, mentions uncommitted changes; nothing else touched.
    printf '\n<!-- dirty tracked change for test case 9a -->\n' >> "$REPO9/README.md"
    OUT9A="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" update 2>&1)"
    RC9A=$?
    CFG9_SHA_AFTER_A="$(shasum -a 256 "$C9/.second-brain/config.json" | cut -d' ' -f1)"
    if [ "$RC9A" -ne 0 ] && printf '%s' "$OUT9A" | grep -qi 'uncommitted' && [ "$CFG9_SHA_BEFORE_A" = "$CFG9_SHA_AFTER_A" ]; then
      pass "9a. dirty throwaway repo (tracked change) -> update (pull enabled) aborts, mentions uncommitted changes, config untouched"
    else
      fail "9a. dirty-repo gate wrong — rc=$RC9A out=[$OUT9A]"
    fi
    (cd "$REPO9" && git checkout -q -- README.md)

    # (a2) an UNTRACKED-only file must NOT count as "dirty" (F4: dirty
    #      check uses --untracked-files=no). It should sail past the dirty
    #      gate straight to the real `git pull --ff-only` attempt, which
    #      fails here only because this throwaway repo has no upstream
    #      tracking branch configured — a different, expected failure, not
    #      the dirty gate (proven by the absence of "uncommitted" in the
    #      message, and the presence of the pull-failure message instead).
    : > "$REPO9/UNTRACKED_ONLY.txt"
    OUT9A2="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9/sbm" update 2>&1)"
    RC9A2=$?
    if [ "$RC9A2" -ne 0 ] && ! printf '%s' "$OUT9A2" | grep -qi 'uncommitted' && printf '%s' "$OUT9A2" | grep -qi 'pull'; then
      pass "9a2. untracked-only file in the repo -> NOT flagged dirty (fails later, at the real git pull, not at the dirty gate)"
    else
      fail "9a2. untracked-files=no dirty gate wrong — rc=$RC9A2 out=[$OUT9A2]"
    fi
    rm -f "$REPO9/UNTRACKED_ONLY.txt"

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

      # (e) F5 regression test: this shell process already `source`d
      # lib/apply.sh (function bodies are bound at source time, not looked
      # up again per call) BEFORE any of the git pulls above happened. Add
      # a sentinel print to apply() in the ORIGINAL repo, commit it, then
      # `update` (pull enabled) on the CLONE again — the sentinel can only
      # show up in the report if the update re-exec'd against the freshly
      # pulled sbm/lib/apply.sh instead of continuing in this already-
      # running process with its stale, pre-pull apply() still in memory.
      # >&2: apply()'s stdout is captured into cmd_update's own report_file
      # and only re-emitted through print_report_summary's fixed set of
      # recognized status lines (ADDED/UPDATED/.../ORPHANED) — an arbitrary
      # extra stdout line would be silently swallowed. stderr passes
      # through untouched, straight into this test's `2>&1` capture.
      perl -i -pe '$_ = qq(  printf "SBM_REEXEC_SENTINEL\\n" >&2\n) . $_ if /^  rm -f "\$current_dests"$/;' "$REPO9/lib/apply.sh"
      (cd "$REPO9" && git add -A && git commit -q -m 'add re-exec sentinel to apply() for test 9e')

      OUT9E="$(CLAUDE_HOME="$C9" HOME="$H9" "$REPO9_CLONE/sbm" update 2>&1)"
      RC9E=$?
      if [ "$RC9E" -eq 0 ] && printf '%s' "$OUT9E" | grep -qF 'SBM_REEXEC_SENTINEL'; then
        pass "9e. update (pull enabled) re-execs against the freshly pulled sbm/lib/apply.sh (sentinel added post-pull shows up in this same run)"
      else
        fail "9e. re-exec-after-pull regression — rc=$RC9E out=[$OUT9E]"
      fi
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
# Case 11 — per-language .md overlay in apply() (F3a), synthetic language "xx"
# =============================================================================
T11="$TDIR/case11"
mkdir -p "$T11"

# --- setup: a repo copy with a PARTIAL xx overlay -------------------------
# messages.env: identical to en/ except ONE value (rendered into an
# installed hook, MSG_CLOSE_STOP_BLOCK -> claude/hooks/check-close.sh)
# carries a marker. claude/commands/start.md: overlaid (marker comment).
# claude/commands/close.md: deliberately NOT overlaid, to exercise the
# English fallback.
REPO11="$T11/repo-xx-partial"
make_repo_copy "$REPO11"
mkdir -p "$REPO11/engine/i18n/xx/claude/commands"
sed 's/^MSG_CLOSE_STOP_BLOCK=/MSG_CLOSE_STOP_BLOCK=XXMARK /' \
  "$REPO11/engine/i18n/en/messages.env" > "$REPO11/engine/i18n/xx/messages.env"
cp "$REPO11/engine/claude/commands/start.md" "$REPO11/engine/i18n/xx/claude/commands/start.md"
printf '\n<!-- XX-OVERLAY -->\n' >> "$REPO11/engine/i18n/xx/claude/commands/start.md"

C11="$T11/c"
H11="$T11/home"
V11="$T11/vault11"
mkdir -p "$C11" "$H11"

OUT11A="$(CLAUDE_HOME="$C11" HOME="$H11" "$REPO11/sbm" install --yes --lang xx --vault "$V11" 2>&1)"
RC11A=$?

C11A_OK=1
[ "$RC11A" -eq 0 ] || { C11A_OK=0; fail "11a. install --lang xx exit != 0 — out=[$OUT11A]"; }
grep -qF 'XX-OVERLAY' "$C11/commands/start.md" 2>/dev/null || { C11A_OK=0; fail "11a. installed commands/start.md missing the xx overlay marker"; }
if grep -qF 'XX-OVERLAY' "$C11/commands/close.md" 2>/dev/null; then
  C11A_OK=0
  fail "11a. commands/close.md unexpectedly has the xx overlay marker (should fall back to English)"
fi

# close.md has no xx pair -> English-fallback render. Reproduce that render
# directly with render_file (sourced above) and diff byte-for-byte.
if [[ "$V11" == "$H11/"* ]]; then
  VD11="~/${V11#"$H11"/}"
  VS11="\$HOME/${V11#"$H11"/}"
else
  VD11="$V11"
  VS11="$V11"
fi
EXPECTED_CLOSE="$T11/expected-close.md"
render_file "$REPO11/engine/claude/commands/close.md" "$EXPECTED_CLOSE" "$REPO11/engine/i18n/en/messages.env" "$VD11" "$VS11" >/dev/null 2>&1
if ! cmp -s "$EXPECTED_CLOSE" "$C11/commands/close.md" 2>/dev/null; then
  C11A_OK=0
  fail "11a. installed commands/close.md doesn't match the plain English render (fallback broken)"
fi

grep -qF 'XXMARK' "$C11/hooks/check-close.sh" 2>/dev/null || { C11A_OK=0; fail "11a. installed hooks/check-close.sh missing XXMARK (messages.env lang override not applied)"; }

LEFTOVER11A="$(grep -rlE '@@[A-Z_]+@@' "$C11" "$V11" 2>/dev/null)"
[ -z "$LEFTOVER11A" ] || { C11A_OK=0; fail "11a. leftover @@..@@ placeholders: $LEFTOVER11A"; }

CFG11_LANG="$(jq -r '.lang' "$C11/.second-brain/config.json" 2>/dev/null)"
[ "$CFG11_LANG" = "xx" ] || { C11A_OK=0; fail "11a. config.json lang != xx — got [$CFG11_LANG]"; }

OUT11A_STATUS="$(CLAUDE_HOME="$C11" HOME="$H11" "$REPO11/sbm" status 2>&1)"
printf '%s' "$OUT11A_STATUS" | grep -q 'xx' || { C11A_OK=0; fail "11a. status output doesn't mention xx — out=[$OUT11A_STATUS]"; }

[ "$C11A_OK" -eq 1 ] && pass "11a. install --lang xx: exit 0, overlay used for start.md, English fallback for close.md, messages.env override reaches an installed hook, no leftover placeholders, config+status show xx"

# --- 11b: switching to --lang en goes through the normal manifest path ---
OUT11B="$(CLAUDE_HOME="$C11" HOME="$H11" "$REPO11/sbm" update --no-pull --lang en 2>&1)"
RC11B=$?
C11B_OK=1
[ "$RC11B" -eq 0 ] || { C11B_OK=0; fail "11b. update --no-pull --lang en exit != 0 — out=[$OUT11B]"; }
printf '%s' "$OUT11B" | grep -qE 'conflict=0 ' || { C11B_OK=0; fail "11b. summary doesn't show conflict=0 — out=[$OUT11B]"; }
if grep -qF 'XX-OVERLAY' "$C11/commands/start.md" 2>/dev/null; then
  C11B_OK=0
  fail "11b. commands/start.md still has the xx marker after switching to lang en"
fi

[ "$C11B_OK" -eq 1 ] && pass "11b. update --no-pull --lang en (nothing hand-touched): exit 0, start.md back to the English render (no marker), conflict=0"

# --- 11c: hand-edit + switch back to --lang xx -> conflict, .new carries
#          the overlay, dest left byte-unchanged ---------------------------
START_DEST="$C11/commands/start.md"
printf '\n<!-- hand-edited by test case 11c -->\n' >> "$START_DEST"
START_BEFORE="$(cat "$START_DEST")"

OUT11C="$(CLAUDE_HOME="$C11" HOME="$H11" "$REPO11/sbm" update --no-pull --lang xx 2>&1)"
RC11C=$?
START_AFTER="$([ -f "$START_DEST" ] && cat "$START_DEST")"

C11C_OK=1
[ "$RC11C" -eq 0 ] || { C11C_OK=0; fail "11c. update --no-pull --lang xx after hand-edit exit != 0 — out=[$OUT11C]"; }
printf '%s' "$OUT11C" | grep -qE 'conflict=1 ' || { C11C_OK=0; fail "11c. summary doesn't show conflict=1 — out=[$OUT11C]"; }
[ -f "$START_DEST.new" ] || { C11C_OK=0; fail "11c. commands/start.md.new not created"; }
grep -qF 'XX-OVERLAY' "$START_DEST.new" 2>/dev/null || { C11C_OK=0; fail "11c. commands/start.md.new missing the xx overlay marker"; }
[ "$START_BEFORE" = "$START_AFTER" ] || { C11C_OK=0; fail "11c. commands/start.md was modified, expected byte-unchanged"; }

[ "$C11C_OK" -eq 1 ] && pass "11c. hand-edit + update --no-pull --lang xx -> conflict=1, start.md.new carries the xx overlay marker, start.md byte-unchanged"

# --- 11d: check-i18n.sh checks 3-6 against a FULL synthetic xx overlay ----
build_full_xx_overlay() {
  local repo="$1"
  mkdir -p "$repo/engine/i18n/xx/claude/commands" "$repo/engine/i18n/xx/claude/agents" "$repo/engine/i18n/xx/method" "$repo/engine/i18n/xx/vault"
  cp "$repo/engine/claude/CLAUDE.md" "$repo/engine/i18n/xx/claude/CLAUDE.md"
  cp "$repo"/engine/claude/commands/*.md "$repo/engine/i18n/xx/claude/commands/"
  cp "$repo"/engine/claude/agents/*.md "$repo/engine/i18n/xx/claude/agents/"
  cp "$repo"/engine/method/*.md "$repo/engine/i18n/xx/method/"
  cp "$repo/engine/vault/home.md" "$repo/engine/i18n/xx/vault/home.md"
}

REPO11D="$T11/repo-xx-full"
make_repo_copy "$REPO11D"
build_full_xx_overlay "$REPO11D"

OUT11D_BASE="$(bash "$SCRIPT_DIR/check-i18n.sh" "$REPO11D" 2>&1)"
RC11D_BASE=$?
if [ "$RC11D_BASE" -eq 0 ]; then
  pass "11d. check-i18n.sh against a full synthetic xx overlay (exact mirror) passes"
else
  fail "11d. check-i18n.sh against a full synthetic xx overlay unexpectedly failed — out=[$OUT11D_BASE]"
fi

# orphan: an i18n/xx file with no English counterpart -> check 6 fails, names it
REPO11D_ORPHAN="$T11/repo-xx-orphan"
cp -R "$REPO11D" "$REPO11D_ORPHAN"
printf '# bogus\n' > "$REPO11D_ORPHAN/engine/i18n/xx/claude/commands/bogus.md"
OUT11D_ORPHAN="$(bash "$SCRIPT_DIR/check-i18n.sh" "$REPO11D_ORPHAN" 2>&1)"
RC11D_ORPHAN=$?
if [ "$RC11D_ORPHAN" -ne 0 ] && printf '%s' "$OUT11D_ORPHAN" | grep -qF 'bogus.md'; then
  pass "11d. orphan i18n/xx file (no English counterpart) -> check-i18n.sh fails, names it"
else
  fail "11d. orphan-file check didn't fail as expected — out=[$OUT11D_ORPHAN]"
fi

# missing pair: removing one pair -> check 3 fails, names lang+file
REPO11D_MISSING="$T11/repo-xx-missing"
cp -R "$REPO11D" "$REPO11D_MISSING"
rm -f "$REPO11D_MISSING/engine/i18n/xx/method/BRAIN.md"
OUT11D_MISSING="$(bash "$SCRIPT_DIR/check-i18n.sh" "$REPO11D_MISSING" 2>&1)"
RC11D_MISSING=$?
if [ "$RC11D_MISSING" -ne 0 ] && printf '%s' "$OUT11D_MISSING" | grep -qF 'FAIL: 3.' && printf '%s' "$OUT11D_MISSING" | grep -qF 'method/BRAIN.md'; then
  pass "11d. removing an i18n/xx pair -> check-i18n.sh fails check 3, names lang+file"
else
  fail "11d. missing-pair check didn't fail as expected — out=[$OUT11D_MISSING]"
fi

# stale method-version: changing it in a pair -> check 4 fails, names lang+file
REPO11D_VER="$T11/repo-xx-badversion"
cp -R "$REPO11D" "$REPO11D_VER"
EN_BRAIN_VERSION="$(grep -oE 'method-version:[[:space:]]*[0-9]+\.[0-9]+' "$REPO11D_VER/engine/method/BRAIN.md" | head -1 | grep -oE '[0-9]+\.[0-9]+')"
NEW_BRAIN_VERSION="${EN_BRAIN_VERSION}9"
perl -pi -e "s/method-version: \Q$EN_BRAIN_VERSION\E/method-version: $NEW_BRAIN_VERSION/" "$REPO11D_VER/engine/i18n/xx/method/BRAIN.md"
OUT11D_VER="$(bash "$SCRIPT_DIR/check-i18n.sh" "$REPO11D_VER" 2>&1)"
RC11D_VER=$?
if [ "$RC11D_VER" -ne 0 ] && printf '%s' "$OUT11D_VER" | grep -qF 'FAIL: 4.' && printf '%s' "$OUT11D_VER" | grep -qF 'method/BRAIN.md'; then
  pass "11d. stale method-version in an i18n/xx pair -> check-i18n.sh fails check 4, names lang+file"
else
  fail "11d. method-version check didn't fail as expected — out=[$OUT11D_VER]"
fi

# dropped @@VAULT@@ token: removing it from a pair -> check 5 fails, names lang+file
REPO11D_TOKEN="$T11/repo-xx-badtoken"
cp -R "$REPO11D" "$REPO11D_TOKEN"
perl -pi -e 's/\@\@VAULT\@\@//g' "$REPO11D_TOKEN/engine/i18n/xx/claude/CLAUDE.md"
OUT11D_TOKEN="$(bash "$SCRIPT_DIR/check-i18n.sh" "$REPO11D_TOKEN" 2>&1)"
RC11D_TOKEN=$?
if [ "$RC11D_TOKEN" -ne 0 ] && printf '%s' "$OUT11D_TOKEN" | grep -qF 'FAIL: 5.' && printf '%s' "$OUT11D_TOKEN" | grep -qF 'claude/CLAUDE.md'; then
  pass "11d. dropped @@VAULT@@ token in an i18n/xx pair -> check-i18n.sh fails check 5, names lang+file"
else
  fail "11d. token-set check didn't fail as expected — out=[$OUT11D_TOKEN]"
fi

# =============================================================================
# Case 12 — real `install --lang es` (engine/i18n/es overlay), status speaks
#           the installed language, English fallback for an unknown lang
# =============================================================================
T12="$TDIR/case12"
C12="$T12/c"
H12="$T12/home"
V12="$H12/second-brain"
mkdir -p "$C12" "$H12"

OUT12A="$(CLAUDE_HOME="$C12" HOME="$H12" "$SBM" install --yes --lang es 2>&1)"
RC12A=$?

C12A_OK=1
[ "$RC12A" -eq 0 ] || { C12A_OK=0; fail "12a. install --lang es exit != 0 — out=[$OUT12A]"; }

CFG12_LANG="$(jq -r '.lang' "$C12/.second-brain/config.json" 2>/dev/null)"
[ "$CFG12_LANG" = "es" ] || { C12A_OK=0; fail "12a. config.json lang != es — got [$CFG12_LANG]"; }

LEFTOVER12A="$(grep -rlE '@@[A-Z0-9_]+@@' "$C12" "$V12" 2>/dev/null)"
[ -z "$LEFTOVER12A" ] || { C12A_OK=0; fail "12a. leftover @@..@@ placeholders: $LEFTOVER12A"; }

grep -qF 'Abrí la sesión según el método de trabajo:' "$C12/commands/start.md" 2>/dev/null \
  || { C12A_OK=0; fail "12a. installed commands/start.md missing distinctive es overlay line"; }

grep -qF '## Estado actual' "$V12/method/CONTEXT.template.md" 2>/dev/null \
  || { C12A_OK=0; fail "12a. vault method/CONTEXT.template.md missing '## Estado actual'"; }

HOME12_MD="$V12/00-index/home.md"
grep -qF '# Home — segundo cerebro' "$HOME12_MD" 2>/dev/null \
  || { C12A_OK=0; fail "12a. vault 00-index/home.md missing '# Home — segundo cerebro' heading (es overlay)"; }
grep -qE '^date:' "$HOME12_MD" 2>/dev/null \
  || { C12A_OK=0; fail "12a. vault 00-index/home.md missing a date: line"; }

BEGIN_COUNT12="$(grep -cF '<!-- BEGIN SECOND BRAIN METHOD -->' "$C12/CLAUDE.md" 2>/dev/null || true)"
[ "$BEGIN_COUNT12" -eq 1 ] || { C12A_OK=0; fail "12a. CLAUDE.md BEGIN marker count != 1 — got $BEGIN_COUNT12"; }

printf '%s' "$OUT12A" | grep -qF 'CÓMO EMPEZAR' \
  || { C12A_OK=0; fail "12a. install output missing Spanish 'CÓMO EMPEZAR' (from es messages.env) — out=[$OUT12A]"; }

[ "$C12A_OK" -eq 1 ] && pass "12a. install --lang es: exit 0, config lang=es, no leftover placeholders, es overlay used for start.md and vault CONTEXT template, single CLAUDE.md block, Spanish install output"

# --- 12b: status speaks the installed language (Spanish) -------------------
OUT12B="$(CLAUDE_HOME="$C12" HOME="$H12" "$SBM" status 2>&1)"
RC12B=$?
C12B_OK=1
[ "$RC12B" -eq 0 ] || { C12B_OK=0; fail "12b. status exit != 0 — out=[$OUT12B]"; }
printf '%s' "$OUT12B" | grep -qF 'ok — sin archivos .new, nada editado desde el último apply.' \
  || { C12B_OK=0; fail "12b. status output not in Spanish — out=[$OUT12B]"; }
[ "$C12B_OK" -eq 1 ] && pass "12b. status after a --lang es install prints Spanish (installed language, not English)"

# --- 12c: update --no-pull --lang en (nothing hand-touched) -> back to English
OUT12C="$(CLAUDE_HOME="$C12" HOME="$H12" "$SBM" update --no-pull --lang en 2>&1)"
RC12C=$?
C12C_OK=1
[ "$RC12C" -eq 0 ] || { C12C_OK=0; fail "12c. update --no-pull --lang en exit != 0 — out=[$OUT12C]"; }
printf '%s' "$OUT12C" | grep -qE 'conflict=0 ' || { C12C_OK=0; fail "12c. summary doesn't show conflict=0 — out=[$OUT12C]"; }
grep -qF 'Open the session per the working method:' "$C12/commands/start.md" 2>/dev/null \
  || { C12C_OK=0; fail "12c. installed commands/start.md not back to English"; }
[ "$C12C_OK" -eq 1 ] && pass "12c. update --no-pull --lang en (nothing touched): exit 0, conflict=0, start.md back to English"

# --- 12d: status after (c) speaks English again -----------------------------
OUT12D="$(CLAUDE_HOME="$C12" HOME="$H12" "$SBM" status 2>&1)"
RC12D=$?
C12D_OK=1
[ "$RC12D" -eq 0 ] || { C12D_OK=0; fail "12d. status exit != 0 — out=[$OUT12D]"; }
printf '%s' "$OUT12D" | grep -qF 'ok — no .new files, nothing edited since the last apply.' \
  || { C12D_OK=0; fail "12d. status output not in English — out=[$OUT12D]"; }
[ "$C12D_OK" -eq 1 ] && pass "12d. status after switching back to --lang en prints English again"

# --- 12e: status with an unknown installed lang in config.json -> English
#          fallback, no crash --------------------------------------------
CFG12E="$C12/.second-brain/config.json"
TMP12E="$(mktemp "$T12/config.XXXXXX")"
jq '.lang = "zz"' "$CFG12E" > "$TMP12E" && mv "$TMP12E" "$CFG12E"
OUT12E="$(CLAUDE_HOME="$C12" HOME="$H12" "$SBM" status 2>&1)"
RC12E=$?
C12E_OK=1
[ "$RC12E" -eq 0 ] || { C12E_OK=0; fail "12e. status with unknown installed lang exit != 0 — out=[$OUT12E]"; }
printf '%s' "$OUT12E" | grep -qF 'ok — no .new files, nothing edited since the last apply.' \
  || { C12E_OK=0; fail "12e. status with unknown installed lang didn't fall back to English — out=[$OUT12E]"; }
[ "$C12E_OK" -eq 1 ] && pass "12e. status with an unknown installed lang (zz) in config.json -> exit 0, English fallback, no crash"

# =============================================================================
# Case 13 — non-empty vault at install time -> scaffold is skipped
#           entirely, a pre-existing home.md is left byte-identical (F4a).
#           V13 has neither method/ nor projects/, so F2's vault guard
#           (case 16 below) would otherwise abort it -> --force is required
#           here (this case is about the scaffold-skip behavior, not the
#           guard itself).
# =============================================================================
T13="$TDIR/case13"
C13="$T13/c"
H13="$T13/home"
V13="$T13/vault13"
mkdir -p "$C13" "$H13" "$V13/00-index"
printf 'user file, not the method\n' > "$V13/00-index/user-note.md"
printf '# My own home\nCustom content, not the method scaffold.\n' > "$V13/00-index/home.md"
HOME13_BEFORE="$(cat "$V13/00-index/home.md")"

OUT13="$(CLAUDE_HOME="$C13" HOME="$H13" "$SBM" install --yes --force --vault "$V13" 2>&1)"
RC13=$?
HOME13_AFTER="$([ -f "$V13/00-index/home.md" ] && cat "$V13/00-index/home.md")"

C13_OK=1
[ "$RC13" -eq 0 ] || { C13_OK=0; fail "13. install into a non-empty vault exit != 0 — out=[$OUT13]"; }
[ "$HOME13_BEFORE" = "$HOME13_AFTER" ] || { C13_OK=0; fail "13. pre-existing home.md was modified, expected byte-unchanged"; }

[ "$C13_OK" -eq 1 ] && pass "13. install --yes --force --vault <non-empty dir>: exit 0, pre-existing 00-index/home.md left byte-identical (scaffold skipped)"

# --- sbm --help advertises --lang en|es -------------------------------------
OUTHELP="$("$SBM" --help 2>&1)"
RCHELP=$?
if [ "$RCHELP" -eq 0 ] && printf '%s' "$OUTHELP" | grep -qF -- '--lang en|es'; then
  pass "14. sbm --help output contains '--lang en|es'"
else
  fail "14. sbm --help doesn't advertise '--lang en|es' — rc=$RCHELP out=[$OUTHELP]"
fi

# =============================================================================
# Case 15 — ./install.sh <path> back-compat (F1): first arg not starting
#           with "-" is translated to --vault <path>, remaining args passed
#           through.
# =============================================================================
T15="$TDIR/case15"
C15="$T15/c"
H15="$T15/home"
V15="$T15/vault15"
mkdir -p "$C15" "$H15"

OUT15="$(CLAUDE_HOME="$C15" HOME="$H15" "$REPO_ROOT/install.sh" "$V15" --yes 2>&1)"
RC15=$?
C15_OK=1
[ "$RC15" -eq 0 ] || { C15_OK=0; fail "15. ./install.sh <path> --yes exit != 0 — out=[$OUT15]"; }
[ -d "$V15/method" ] || { C15_OK=0; fail "15. ./install.sh <path> didn't install into <path> — $V15/method missing"; }
CFG15_VAULT="$(jq -r '.vault' "$C15/.second-brain/config.json" 2>/dev/null)"
[ "$CFG15_VAULT" = "$V15" ] || { C15_OK=0; fail "15. config vault != given path — got [$CFG15_VAULT] want [$V15]"; }

[ "$C15_OK" -eq 1 ] && pass "15. ./install.sh <path> --yes (back-compat): installs into <path>, remaining flags (--yes) passed through"

# =============================================================================
# Case 16 — vault guard (F2): a non-empty dir with neither method/ nor
#           projects/ is refused unless --force; a dir with projects/ is
#           adopted without asking.
# =============================================================================
T16="$TDIR/case16"
C16A="$T16/c-a"
H16A="$T16/home-a"
V16A="$T16/foreign-vault"
mkdir -p "$C16A" "$H16A" "$V16A"
printf 'not a vault, just some random file\n' > "$V16A/random.txt"

OUT16A="$(CLAUDE_HOME="$C16A" HOME="$H16A" "$SBM" install --yes --vault "$V16A" 2>&1)"
RC16A=$?
C16A_OK=1
[ "$RC16A" -ne 0 ] || { C16A_OK=0; fail "16a. install --yes into a foreign non-empty vault didn't abort — out=[$OUT16A]"; }
printf '%s' "$OUT16A" | grep -qF -- '--force' || { C16A_OK=0; fail "16a. abort message doesn't mention --force — out=[$OUT16A]"; }
[ ! -d "$V16A/method" ] || { C16A_OK=0; fail "16a. vault/method/ was written despite the abort"; }
[ ! -f "$C16A/.second-brain/config.json" ] || { C16A_OK=0; fail "16a. config.json was written despite the abort"; }
[ ! -d "$V16A/.git" ] || { C16A_OK=0; fail "16a. vault .git was created despite the abort"; }

[ "$C16A_OK" -eq 1 ] && pass "16a. install --yes into a non-empty, non-vault dir (no method/ or projects/) aborts, mentions --force, nothing written"

OUT16B="$(CLAUDE_HOME="$C16A" HOME="$H16A" "$SBM" install --yes --force --vault "$V16A" 2>&1)"
RC16B=$?
C16B_OK=1
[ "$RC16B" -eq 0 ] || { C16B_OK=0; fail "16b. install --yes --force into the same foreign vault failed — out=[$OUT16B]"; }
[ -d "$V16A/method" ] || { C16B_OK=0; fail "16b. --force didn't adopt the vault (method/ missing)"; }
grep -qF 'random file' "$V16A/random.txt" 2>/dev/null || { C16B_OK=0; fail "16b. --force touched the pre-existing random.txt"; }

[ "$C16B_OK" -eq 1 ] && pass "16b. install --yes --force into the same non-vault dir proceeds and adopts it"

C16C="$T16/c-c"
H16C="$T16/home-c"
V16C="$T16/real-vault"
mkdir -p "$C16C" "$H16C" "$V16C/projects"
printf 'looks like a project\n' > "$V16C/projects/marker.txt"
OUT16C="$(CLAUDE_HOME="$C16C" HOME="$H16C" "$SBM" install --yes --vault "$V16C" 2>&1)"
RC16C=$?
C16C_OK=1
[ "$RC16C" -eq 0 ] || { C16C_OK=0; fail "16c. install --yes into a dir with projects/ was blocked — out=[$OUT16C]"; }
[ -f "$V16C/projects/marker.txt" ] || { C16C_OK=0; fail "16c. pre-existing projects/marker.txt lost"; }

[ "$C16C_OK" -eq 1 ] && pass "16c. install --yes into a dir with an existing projects/ folder is adopted without a prompt (no --force needed)"

# =============================================================================
# Case 17 — a relative --vault path is resolved to an absolute path against
#           the cwd (F3), stored absolute in config.json.
# =============================================================================
T17="$TDIR/case17"
C17="$T17/c"
H17="$T17/home"
CWD17="$T17/somewhere"
mkdir -p "$C17" "$H17" "$CWD17"

OUT17="$(cd "$CWD17" && CLAUDE_HOME="$C17" HOME="$H17" "$SBM" install --yes --vault "relvault17" 2>&1)"
RC17=$?
C17_OK=1
[ "$RC17" -eq 0 ] || { C17_OK=0; fail "17. install --vault <relative> exit != 0 — out=[$OUT17]"; }
EXPECTED_V17="$CWD17/relvault17"
CFG17_VAULT="$(jq -r '.vault' "$C17/.second-brain/config.json" 2>/dev/null)"
[ "$CFG17_VAULT" = "$EXPECTED_V17" ] || { C17_OK=0; fail "17. config vault not resolved against cwd — got [$CFG17_VAULT] want [$EXPECTED_V17]"; }
case "$CFG17_VAULT" in
  /*) : ;;
  *) C17_OK=0; fail "17. config vault isn't an absolute path: [$CFG17_VAULT]" ;;
esac
[ -d "$EXPECTED_V17/method" ] || { C17_OK=0; fail "17. vault wasn't actually created at the resolved absolute path"; }

[ "$C17_OK" -eq 1 ] && pass "17. install --vault <relative path>: resolved to an absolute path against cwd, stored in config.json, vault created there"

# =============================================================================
# Case 18 — a flag that needs a value ("--lang"/"--vault") as the LAST arg,
#           or followed by another flag, is a usage error (F9), never a
#           silent exit.
# =============================================================================
T18="$TDIR/case18"
C18="$T18/c"
H18="$T18/home"
mkdir -p "$C18" "$H18"

OUT18A="$(CLAUDE_HOME="$C18" HOME="$H18" "$SBM" install --vault 2>&1)"
RC18A=$?
C18_OK=1
[ "$RC18A" -eq 1 ] || { C18_OK=0; fail "18a. sbm install --vault (no value, last arg) exit != 1 — rc=$RC18A out=[$OUT18A]"; }
printf '%s' "$OUT18A" | grep -qi -- '--vault' || { C18_OK=0; fail "18a. error message doesn't name --vault — out=[$OUT18A]"; }
[ ! -f "$C18/.second-brain/config.json" ] || { C18_OK=0; fail "18a. config.json written despite the missing-value error"; }

OUT18B="$(CLAUDE_HOME="$C18" HOME="$H18" "$SBM" install --lang --yes 2>&1)"
RC18B=$?
if [ "$RC18B" -eq 1 ] && printf '%s' "$OUT18B" | grep -qi -- '--lang'; then
  : # ok
else
  C18_OK=0
  fail "18b. sbm install --lang --yes (value looks like a flag) didn't error — rc=$RC18B out=[$OUT18B]"
fi

[ "$C18_OK" -eq 1 ] && pass "18. --vault/--lang with no usable value (last arg, or followed by another flag) -> usage error, exit 1, never a silent exit"

# =============================================================================
# Case 19 — installed permissions (F10): 0644 for regular managed files,
#           0755 for hooks/scripts, regardless of mktemp's 0600 default.
# =============================================================================
T19="$TDIR/case19"
C19="$T19/c"
H19="$T19/home"
V19="$T19/vault19"
mkdir -p "$C19" "$H19"
OUT19="$(CLAUDE_HOME="$C19" HOME="$H19" "$SBM" install --yes --vault "$V19" 2>&1)"
RC19=$?
C19_OK=1
[ "$RC19" -eq 0 ] || { C19_OK=0; fail "19. setup install failed — out=[$OUT19]"; }
CMD_MODE19="$(stat -f '%Lp' "$C19/commands/close.md" 2>/dev/null)"
HOOK_MODE19="$(stat -f '%Lp' "$C19/hooks/check-close.sh" 2>/dev/null)"
[ "$CMD_MODE19" = "644" ] || { C19_OK=0; fail "19. commands/close.md mode != 644 — got $CMD_MODE19"; }
[ "$HOOK_MODE19" = "755" ] || { C19_OK=0; fail "19. hooks/check-close.sh mode != 755 — got $HOOK_MODE19"; }
CLAUDEMD_MODE19="$(stat -f '%Lp' "$C19/CLAUDE.md" 2>/dev/null)"
[ "$CLAUDEMD_MODE19" = "644" ] || { C19_OK=0; fail "19. new CLAUDE.md mode != 644 — got $CLAUDEMD_MODE19"; }

[ "$C19_OK" -eq 1 ] && pass "19. installed command file + new CLAUDE.md mode 644, hook mode 755 (not mktemp's 0600)"

# =============================================================================
# Case 20 — CLAUDE.md managed-block edit detection (F6): a hand-edit INSIDE
#           the block conflicts (.new written, dest untouched); --take-new
#           backs it up and replaces it; an unedited block updates in place
#           with no conflict when the engine's rendered block changes.
# =============================================================================
T20="$TDIR/case20"
C20="$T20/c"
H20="$T20/home"
V20="$T20/vault20"
mkdir -p "$C20" "$H20"
OUT20I="$(CLAUDE_HOME="$C20" HOME="$H20" "$SBM" install --yes --vault "$V20" 2>&1)"
RC20I=$?
C20_OK=1
[ "$RC20I" -eq 0 ] || { C20_OK=0; fail "20. setup install failed — out=[$OUT20I]"; }

perl -pi -e 's/(<!-- BEGIN SECOND BRAIN METHOD -->)/$1\n<!-- hand-edited inside the block, case 20a -->/' "$C20/CLAUDE.md"
CLAUDEMD20_BEFORE="$(cat "$C20/CLAUDE.md")"

OUT20A="$(CLAUDE_HOME="$C20" HOME="$H20" "$SBM" update --no-pull 2>&1)"
RC20A=$?
CLAUDEMD20_AFTER="$(cat "$C20/CLAUDE.md")"
[ "$RC20A" -eq 0 ] || { C20_OK=0; fail "20a. update after in-block hand-edit exit != 0 — out=[$OUT20A]"; }
printf '%s' "$OUT20A" | grep -qE 'conflict=1 ' || { C20_OK=0; fail "20a. summary doesn't show conflict=1 — out=[$OUT20A]"; }
[ -f "$C20/CLAUDE.md.new" ] || { C20_OK=0; fail "20a. CLAUDE.md.new not created"; }
[ "$CLAUDEMD20_BEFORE" = "$CLAUDEMD20_AFTER" ] || { C20_OK=0; fail "20a. CLAUDE.md was modified, expected byte-unchanged"; }
if grep -qF 'hand-edited inside the block, case 20a' "$C20/CLAUDE.md.new" 2>/dev/null; then
  C20_OK=0
  fail "20a. CLAUDE.md.new still carries the stale hand-edit (should be the fresh render)"
fi

[ "$C20_OK" -eq 1 ] && pass "20a. hand-edit inside the CLAUDE.md managed block -> update conflict=1, CLAUDE.md.new written, CLAUDE.md byte-unchanged"

OUT20B="$(CLAUDE_HOME="$C20" HOME="$H20" "$SBM" update --no-pull --take-new 2>&1)"
RC20B=$?
C20B_OK=1
[ "$RC20B" -eq 0 ] || { C20B_OK=0; fail "20b. update --take-new exit != 0 — out=[$OUT20B]"; }
[ ! -f "$C20/CLAUDE.md.new" ] || { C20B_OK=0; fail "20b. CLAUDE.md.new still present after --take-new"; }
if grep -qF 'hand-edited inside the block, case 20a' "$C20/CLAUDE.md" 2>/dev/null; then
  C20B_OK=0
  fail "20b. CLAUDE.md still contains the hand-edit after --take-new"
fi
BACKUP20_FOUND="$(find "$C20/.second-brain/backups" -type f -name 'CLAUDE.md' 2>/dev/null | head -1)"
[ -n "$BACKUP20_FOUND" ] || { C20B_OK=0; fail "20b. no backup of the hand-edited CLAUDE.md found"; }
grep -qF 'hand-edited inside the block, case 20a' "$BACKUP20_FOUND" 2>/dev/null || { C20B_OK=0; fail "20b. backup doesn't contain the pre-take-new hand-edit"; }

[ "$C20B_OK" -eq 1 ] && pass "20b. update --take-new on a hand-edited block -> TAKEN, old content backed up, block replaced"

REPO20="$TDIR/repo-copy-20"
make_repo_copy "$REPO20"
printf '\n<!-- engine-side change for test case 20c -->\n' >> "$REPO20/engine/claude/CLAUDE.md"

OUT20C="$(CLAUDE_HOME="$C20" HOME="$H20" "$REPO20/sbm" update --no-pull 2>&1)"
RC20C=$?
C20C_OK=1
[ "$RC20C" -eq 0 ] || { C20C_OK=0; fail "20c. update after an unedited engine-side CLAUDE.md change exit != 0 — out=[$OUT20C]"; }
printf '%s' "$OUT20C" | grep -qE 'conflict=0 ' || { C20C_OK=0; fail "20c. summary shows a conflict for an unedited block — out=[$OUT20C]"; }
[ ! -f "$C20/CLAUDE.md.new" ] || { C20C_OK=0; fail "20c. CLAUDE.md.new unexpectedly created for an unedited block"; }
grep -qF 'engine-side change for test case 20c' "$C20/CLAUDE.md" 2>/dev/null || { C20C_OK=0; fail "20c. the new engine-side content wasn't applied"; }

[ "$C20C_OK" -eq 1 ] && pass "20c. unedited CLAUDE.md block + an engine-side change -> plain update, no conflict"

# =============================================================================
# Case 21 — stale .new cleanup (F8): resolving a conflict by hand (copying
#           .new over dest) makes the next update recognize the file as
#           already matching, remove the leftover .new, print no spurious
#           UPDATED for that no-op, and leave `status` clean.
# =============================================================================
CONFLICT_DEST21="$MC/commands/close.md"
printf '\n<!-- hand-edited by test case 21 -->\n' >> "$CONFLICT_DEST21"

OUT21A="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC21A=$?
C21_OK=1
[ "$RC21A" -eq 0 ] || { C21_OK=0; fail "21. setup — update to (re)create the conflict failed — out=[$OUT21A]"; }
[ -f "$CONFLICT_DEST21.new" ] || { C21_OK=0; fail "21. setup — commands/close.md.new not created"; }

# Resolve by hand: take the rendered .new as-is.
cp "$CONFLICT_DEST21.new" "$CONFLICT_DEST21"
rm -f "$CONFLICT_DEST21.new"

OUT21B="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" update --no-pull 2>&1)"
RC21B=$?
[ "$RC21B" -eq 0 ] || { C21_OK=0; fail "21. update after hand-resolving the conflict exit != 0 — out=[$OUT21B]"; }
printf '%s' "$OUT21B" | grep -qE 'updated=0 ' || { C21_OK=0; fail "21. no-op resolution reported as updated (spurious UPDATED) — out=[$OUT21B]"; }
[ ! -f "$CONFLICT_DEST21.new" ] || { C21_OK=0; fail "21. commands/close.md.new leftover after the file already matched"; }

OUT21S="$(CLAUDE_HOME="$MC" HOME="$MH" "$SBM" status 2>&1)"
RC21S=$?
[ "$RC21S" -eq 0 ] || { C21_OK=0; fail "21. status after resolution exit != 0 — out=[$OUT21S]"; }
if printf '%s' "$OUT21S" | grep -qF "$CONFLICT_DEST21"; then
  C21_OK=0
  fail "21. status still lists commands/close.md as pending/edited after resolution — out=[$OUT21S]"
fi

[ "$C21_OK" -eq 1 ] && pass "21. resolving a conflict by copying .new over dest: next update recognizes it as a no-op (no spurious UPDATED), removes the leftover .new, status stops listing it"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
exit $?
