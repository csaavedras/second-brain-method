#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash -n "$ROOT/install.sh"
find "$ROOT/engine" "$ROOT/tests" -name '*.sh' -print0 | xargs -0 -n1 bash -n
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$ROOT/tests" -p 'test_*.py' -v
