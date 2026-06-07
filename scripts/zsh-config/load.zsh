#!/bin/zsh

# Load all zsh configuration modules
ZSH_CONFIG_DIR="${0:A:h}"

# PATH first so every module below (and claude-switch) sees ~/.local/bin.
source "$ZSH_CONFIG_DIR/path.zsh"

# Load keybindings
source "$ZSH_CONFIG_DIR/keybindings/bindkey.zsh"

# Load tools
source "$ZSH_CONFIG_DIR/tools/bat.zsh"
source "$ZSH_CONFIG_DIR/tools/eza.zsh"
source "$ZSH_CONFIG_DIR/tools/dust.zsh"
# atuin is sourced from ~/.zshrc AFTER oh-my-zsh so OMZ's `bindkey -e` doesn't
# wipe atuin's ^R / up-arrow widgets off the emacs keymap.
source "$ZSH_CONFIG_DIR/tools/fzf.zsh"
source "$ZSH_CONFIG_DIR/tools/fd.zsh"
source "$ZSH_CONFIG_DIR/tools/fzf-git.zsh"
source "$ZSH_CONFIG_DIR/tools/fzf-preview.zsh"
source "$ZSH_CONFIG_DIR/tools/thefuck.zsh"
source "$ZSH_CONFIG_DIR/tools/claude-switch/claude-switch.zsh"

# Load development tools
source "$ZSH_CONFIG_DIR/development/fnm.zsh"
source "$ZSH_CONFIG_DIR/development/go.zsh"

# Load git tools
source "$ZSH_CONFIG_DIR/git/worktree.zsh"

# Load utilities
source "$ZSH_CONFIG_DIR/utilities/ffmpeg.zsh"
source "$ZSH_CONFIG_DIR/utilities/cmux.zsh"

# zoxide last so its chpwd hook is registered after every other tool's hooks.
source "$ZSH_CONFIG_DIR/tools/zoxide.zsh"