#!/bin/bash
# Legacy entry point; provider protocol belongs to the Claude adapter.
set -euo pipefail
exec bash "${CLAUDE_HOME:-$HOME/.claude}/hooks/second-brain-check-close.sh" "$@"
