#!/bin/bash
# install.sh — alias for `./sbm install`. Kept for backward compatibility
# with existing bookmarks/docs; see README.md and ./sbm install --help
# (i.e. `sbm` with no args) for the current usage.
#
# Back-compat: `./install.sh <path>` (first arg not starting with "-") is
# translated to `./sbm install --vault <path>`, with any remaining args
# passed through as-is (so `./install.sh ~/v --force` still works).
DIR="$(dirname "${BASH_SOURCE[0]}")"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  VAULT_ARG="$1"
  shift
  exec "$DIR/sbm" install --vault "$VAULT_ARG" "$@"
fi
exec "$DIR/sbm" install "$@"
