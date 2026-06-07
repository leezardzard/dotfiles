#!/bin/zsh
#
# Entry point for the modular zsh config.
#
# CONVENTION OVER REGISTRY: every *.zsh under this dir is auto-sourced — drop a
# new module in and it loads, no edit here. Only the handful of modules whose
# load ORDER matters are pinned explicitly; everything else is sourced
# alphabetically in between. Modules are sourced at top level (not inside a
# function) so their assignments and options land in the interactive shell.

ZSH_CONFIG_DIR="${0:A:h}"

# Pinned, order-sensitive modules — sourced explicitly and skipped by the glob:
#   path   — must run first so every later module sees ~/.local/bin
#   claude — puts ~/.local/bin on PATH for the native Claude Code binary; must
#            precede anything downstream that resolves `claude`
#   zoxide — must run LAST so its chpwd hook registers after all other hooks
source "$ZSH_CONFIG_DIR/path.zsh"
source "$ZSH_CONFIG_DIR/tools/claude.zsh"

# Auto-source the rest, sorted (alphabetical) for reproducibility. The skip list
# below covers this file, the pinned modules, and atuin — atuin must load from
# ~/.zshrc AFTER oh-my-zsh, else OMZ's `bindkey -e` wipes atuin's ^R / up-arrow
# widgets off the emacs keymap.
for f in "$ZSH_CONFIG_DIR"/**/*.zsh(.N); do
  case "${f:t}" in
    load.zsh|path.zsh|claude.zsh|zoxide.zsh|atuin.zsh) continue ;;
  esac
  source "$f"
done
unset f

# zoxide last so its chpwd hook is registered after every other tool's hooks.
source "$ZSH_CONFIG_DIR/tools/zoxide.zsh"
