#!/bin/bash
# Second Brain Method v4.0. Default remains Claude for v3 callers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
for dependency in git jq python3; do
  command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
exec python3 "$SCRIPT_DIR/scripts/install.py" "$@"
