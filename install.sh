#!/bin/bash
# install.sh — alias for `./sbm install`. Kept for backward compatibility
# with existing bookmarks/docs; see README.md and ./sbm install --help
# (i.e. `sbm` with no args) for the current usage.
exec "$(dirname "${BASH_SOURCE[0]}")/sbm" install "$@"
