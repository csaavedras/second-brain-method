#!/bin/bash
# install.sh — Installs the "second brain" method for Claude Code on your Mac
# and creates an empty vault ready to use. macOS only.
#
# Usage:  ./install.sh [VAULT_PATH]
#         By default the vault is created at ~/second-brain
#
# What it does: installs the method config into ~/.claude (backing up whatever
# was there), MERGES the method's 2 hooks into your settings.json without
# clobbering your config, and creates the vault (folders + home + git init).
# It uploads nothing and writes no secrets. See README.md for the walkthrough.
set -euo pipefail

# --- args -------------------------------------------------------------------
VAULT_PATH="$HOME/second-brain"
FORCE=0
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    -*)      echo "✗ unknown flag: $a"; exit 1 ;;
    *)       VAULT_PATH="${a/#\~/$HOME}" ;;
  esac
done

CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/engine"
BAKED_VAULT="second-brain"   # baked-in path sentinel to repoint

# --- requirements -----------------------------------------------------------
[ "$(uname)" = "Darwin" ] || { echo "✗ This installer is macOS only."; exit 1; }
[ -d "$ENGINE" ] || { echo "✗ can't find engine/ next to install.sh. Did you clone the whole repo?"; exit 1; }
command -v git >/dev/null || { echo "✗ git is missing."; exit 1; }
command -v jq  >/dev/null || { echo "✗ jq is missing (install with:  brew install jq)."; exit 1; }
command -v claude >/dev/null || echo "⚠ can't find the 'claude' CLI — install Claude Code before using the method."

echo "▸ Method → $CLAUDE_DIR"
echo "▸ Vault  → $VAULT_PATH"
echo ""

# --- 1. back up previous config --------------------------------------------
HAD_CLAUDEMD=0
if [ -e "$CLAUDE_DIR/CLAUDE.md" ] || [ -d "$CLAUDE_DIR/commands" ]; then
  BK="$CLAUDE_DIR/backups/pre-method-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BK"
  for p in CLAUDE.md settings.json commands agents hooks; do
    [ -e "$CLAUDE_DIR/$p" ] && cp -R "$CLAUDE_DIR/$p" "$BK/"
  done
  [ -e "$CLAUDE_DIR/CLAUDE.md" ] && HAD_CLAUDEMD=1
  echo "▸ Backed up your previous config → $BK"
fi

# --- 2. abort if the vault already exists with content ---------------------
if [ -d "$VAULT_PATH" ] && [ -n "$(ls -A "$VAULT_PATH" 2>/dev/null)" ] && [ "$FORCE" -ne 1 ]; then
  echo "✗ $VAULT_PATH already exists and is not empty. Use --force to reinstall the scaffold."
  exit 1
fi

# --- 3. install the method config ------------------------------------------
echo "▸ Installing commands, agents and hooks into $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/agents" "$CLAUDE_DIR/hooks"
cp "$ENGINE/claude/CLAUDE.md"            "$CLAUDE_DIR/CLAUDE.md"
cp "$ENGINE"/claude/commands/*.md        "$CLAUDE_DIR/commands/"
cp "$ENGINE"/claude/agents/*.md          "$CLAUDE_DIR/agents/"
cp "$ENGINE/claude/hooks/check-close.sh" "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/check-close.sh"

# --- 4. MERGE the method's hooks into your settings.json (no clobber) ------
echo "▸ Merging the method's hooks into settings.json (preserves your config)"
USER_S="$CLAUDE_DIR/settings.json"
DIST_S="$ENGINE/claude/settings.json"
if [ -f "$USER_S" ]; then
  TMP="$(mktemp)"
  jq -s '
    .[0] as $u | .[1] as $d
    | $u
    | .hooks = (.hooks // {})
    | .hooks.Stop       = (((.hooks.Stop // [])       | map(select(([.hooks[]?.command] | join(" ") | test("check-close")) | not))) + $d.hooks.Stop)
    | .hooks.PreCompact = (((.hooks.PreCompact // []) | map(select(([.hooks[]?.command] | join(" ") | test("check-close")) | not))) + $d.hooks.PreCompact)
  ' "$USER_S" "$DIST_S" > "$TMP" && mv "$TMP" "$USER_S"
else
  cp "$DIST_S" "$USER_S"
fi

# --- 5. scaffold the vault --------------------------------------------------
echo "▸ Creating the vault at $VAULT_PATH"
mkdir -p "$VAULT_PATH"/{projects,learning/til,learning/concept,patterns,briefs,00-index}
cp -R "$ENGINE/method" "$VAULT_PATH/method"
chmod +x "$VAULT_PATH"/method/scripts/*.sh 2>/dev/null || true

cat > "$VAULT_PATH/.gitignore" <<'EOF'
.DS_Store
.trash/
.obsidian/workspace*
.obsidian/cache
EOF

if [ ! -f "$VAULT_PATH/00-index/home.md" ]; then
cat > "$VAULT_PATH/00-index/home.md" <<EOF
---
type: moc
date: $(date +%Y-%m-%d)
tags: [meta]
---
# Home — second brain

Entry point of the vault. Structure and rules: \`method/BRAIN.md\`.
Study capture: \`/learn\`. Each project's state: its
\`projects/<project>/CONTEXT.md\`.

## Active projects
- (none yet — run \`/new-project\` in the repo where you'll work)

## Study topics (MOCs)
- (created when a topic gathers 3+ notes — MOC rule in BRAIN.md)

## Patterns
- (cross-cutting recipes born from projects — \`patterns/\`)
EOF
fi

# --- 6. repoint the vault path in the config -------------------------------
if [[ "$VAULT_PATH" == "$HOME/"* ]]; then
  DISPLAY="~/${VAULT_PATH#$HOME/}"
  SHELLF="\$HOME/${VAULT_PATH#$HOME/}"
else
  DISPLAY="$VAULT_PATH"; SHELLF="$VAULT_PATH"
fi
if [ "~/$BAKED_VAULT" != "$DISPLAY" ]; then
  echo "▸ Adjusting the method's paths to the vault ($DISPLAY)"
  FILES=("$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR"/commands/*.md \
         "$VAULT_PATH/method/scripts/brain-health.sh")
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    sed -i '' "s#~/$BAKED_VAULT#$DISPLAY#g; s#\\\$HOME/$BAKED_VAULT#$SHELLF#g" "$f"
  done
fi

# --- 7. git init ------------------------------------------------------------
[ -d "$VAULT_PATH/.git" ] || { git -C "$VAULT_PATH" init -q; echo "▸ git init in the vault"; }

# --- 8. verification --------------------------------------------------------
echo ""
echo "▸ Verification:"
if [ "~/$BAKED_VAULT" != "$DISPLAY" ] \
   && grep -rIl "$BAKED_VAULT" "$CLAUDE_DIR"/CLAUDE.md "$CLAUDE_DIR"/commands/*.md >/dev/null 2>&1; then
  echo "  ✗ some paths were not adjusted — check by hand"; exit 1
fi
echo "  ok — commands installed, hooks merged, vault paths OK"
echo ""
echo "  Vault:"
find "$VAULT_PATH" -maxdepth 2 -type d -not -path '*/.git*' | sed "s#$VAULT_PATH#    .#"

# --- 9. next steps ----------------------------------------------------------
cat <<EOF

✓ Method installed. The vault lives at $VAULT_PATH

HOW TO START
  1. (optional) Open $VAULT_PATH in Obsidian → "Open folder as vault".
  2. Keep the per-repo anchor out of your projects' git (global gitignore):
       git config --global core.excludesFile ~/.gitignore_global
       printf 'CLAUDE.local.md\n.claude/settings.local.json\n' >> ~/.gitignore_global
  3. Go into any project and start:
       cd <your-repo> && claude
       /new-project <name>       # registers the project in the vault
       /start                    # opens the session
  4. Work the cycle: plan → task → /close  (and /learn when you learn something).
EOF
if [ "$HAD_CLAUDEMD" -eq 1 ]; then
  cat <<EOF

⚠ You already had your own ~/.claude/CLAUDE.md: it's saved in the backup
  above. The method installed its own; if you had your own rules, re-add
  them by hand to the new CLAUDE.md.
EOF
fi
