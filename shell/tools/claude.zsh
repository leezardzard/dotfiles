###############################################################################
# Claude Code (native install)
# The native installer (curl -fsSL https://claude.ai/install.sh | bash) drops
# the `claude` binary in ~/.local/bin. Put that on PATH so `claude` resolves in
# every shell. Idempotent: only prepend when it isn't already present.
###############################################################################
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
