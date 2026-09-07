#!/bin/bash
# Facts only: the adapters translate stdout JSON into provider protocols.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec python3 "$SCRIPT_DIR/close_core.py" "$@"
