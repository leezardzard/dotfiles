###############################################################################
# Ensure ~/.local/bin is on PATH
###############################################################################
# The Claude Code native installer drops its launcher at ~/.local/bin/claude
# (a shim into ~/.local/share/claude/versions/*). That dir is NOT added by
# .zprofile or the OMZ .zshrc, so outside cmux's injected environment `claude`
# (and anything else installed there) is unreachable — "claude not found in
# PATH". Prepend it idempotently so the native install wins and re-sourcing
# this file doesn't stack duplicates.
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
