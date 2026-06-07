#!/bin/zsh
#
# Wire every tracked dotfile into $HOME via idempotent, loop-safe symlinks.
#
#   ./scripts/link-dotfiles.zsh           # apply links (default)
#   ./scripts/link-dotfiles.zsh status    # report each target, change nothing
#
# The MANIFEST below is the single source of truth for WHAT gets linked — add a
# line here and both `apply` and `status` pick it up. The linking primitives
# live in scripts/lib/link.zsh. REPO_ROOT is derived from this script's own
# location, so it works regardless of the current directory.

set -u

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
source "$SCRIPT_DIR/lib/link.zsh"

# Manifest: "<repo-relative-source>|<absolute-target>".
# Per-app leaves only — NEVER the whole ~/.config (see guard_config_symlink).
typeset -a MANIFEST
MANIFEST=(
  ".p10k.zsh|$HOME/.p10k.zsh"
  ".tmux.conf|$HOME/.tmux.conf"
  ".tmux.powerline.conf|$HOME/.tmux.powerline.conf"
  ".config/ghostty|$HOME/.config/ghostty"
  ".config/cmux|$HOME/.config/cmux"
  ".config/nvim|$HOME/.config/nvim"
  ".config/fresh|$HOME/.config/fresh"
  "scripts/claude/statusline-command.sh|$HOME/.claude/statusline-command.sh"
)

link_apply() {
  guard_config_symlink || return 1
  print "Linking dotfiles from $REPO_ROOT:"
  local pair
  for pair in "${MANIFEST[@]}"; do
    link "${pair%%|*}" "${pair#*|}"
  done
}

link_report() {
  print "Dotfile link status ($REPO_ROOT):"
  local pair
  for pair in "${MANIFEST[@]}"; do
    link_status "${pair%%|*}" "${pair#*|}"
  done
}

main() {
  case "${1:-apply}" in
    apply)        link_apply ;;
    status|check) link_report ;;
    *) print -u2 "usage: ${0:t} [apply|status]"; return 2 ;;
  esac
}

main "$@"
