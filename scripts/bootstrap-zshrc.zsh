#!/bin/zsh

source ./scripts/utils/homebrew_util.zsh

###############################################################################
# Install oh my zsh theme packages
###############################################################################
if [ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

if [ -f ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.backup
fi
cp ./template/.zshrc ~/.zshrc
THEME="powerlevel10k\/powerlevel10k"
sed -i.bu "s/^ZSH_THEME=\".*\"/ZSH_THEME=\"$THEME\"/" ~/.zshrc
rm ~/.zshrc.bu
source ~/.zshrc
echo "Edited line in ~/.zshrc :"
cat ~/.zshrc | grep -m 1 ZSH_THEME

###############################################################################
# Wire tracked dotfiles into $HOME (p10k, tmux, ghostty, cmux, nvim, claude
# statusline) via the single declarative manifest in scripts/link-dotfiles.zsh.
# Idempotent and loop-safe; replaces the old hand-rolled per-file blocks. The
# linker aborts with guidance if ~/.config is a whole-dir symlink into the repo
# (the source of the historical "Too many levels of symbolic links" failures).
###############################################################################
./scripts/link-dotfiles.zsh apply

###############################################################################
# Point every settings.json (default config + each claude-switch profile) at
# the portable "$HOME"-relative statusLine command — makes it portable across
# devices (different usernames). The symlink itself is created by the linker
# above. Runtime deps: jq (Brewfile core) and ccusage via npx (Node/fnm).
# Three cases, idempotent:
#   - no statusLine set       -> install {type: command, command: ...}
#   - ours, hardcoded path    -> rewrite command to the portable form
#   - a different custom one  -> leave it untouched
###############################################################################
if [ -f "$(pwd)/home/.claude/statusline-command.sh" ]; then
  if command -v jq >/dev/null 2>&1; then
    PORTABLE_CMD='bash "$HOME/.claude/statusline-command.sh"'
    # Ensure the default settings.json exists so we can install into it.
    [ -f ~/.claude/settings.json ] || echo '{}' >~/.claude/settings.json
    for settings in ~/.claude/settings.json ~/.claude-profiles/*/.claude/settings.json(N); do
      [ -f "$settings" ] || continue
      cur=$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null) || continue
      filter="" action=""
      case "$cur" in
        "")                      filter='.statusLine = {type: "command", command: $c}'; action="Installed" ;;
        *statusline-command.sh*) [ "$cur" = "$PORTABLE_CMD" ] && continue
                                 filter='.statusLine.command = $c';                     action="Patched"   ;;
        *)                       continue ;;  # different custom status line — leave it
      esac
      tmp="$settings.tmp.$$"
      if jq --arg c "$PORTABLE_CMD" "$filter" "$settings" >"$tmp" 2>/dev/null; then
        mv "$tmp" "$settings"
        echo "$action statusLine command in $settings"
      else
        rm -f "$tmp"
      fi
    done
  fi
fi

###############################################################################
# Install zsh plugins
###############################################################################
brew install zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

###############################################################################
# Install bat (better version of cat)
###############################################################################
brew install bat
mkdir -p "$(bat --config-dir)/themes"
cd "$(bat --config-dir)/themes" &&
  curl -O https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme &&
  bat cache --build &&
  cd -

###############################################################################
# Install zoxide (cache the visited path)
# https://github.com/ajeetdsouza/zoxide
###############################################################################
brew install zoxide

###############################################################################
# Install eza (better version of ls)
# https://github.com/eza-community/eza
###############################################################################
brew install eza

###############################################################################
# Install dust (better version of df)
# https://github.com/bootandy/dust
###############################################################################
brew install dust

###############################################################################
# Install atuin (better version of history)
# https://github.com/atuinsh/atuin
###############################################################################
brew install atuin

###############################################################################
# Install fzf
###############################################################################
brew install fzf

###############################################################################
# Install fd to instead of fzf
# https://github.com/sharkdp/fd
###############################################################################
brew install fd

###############################################################################
# Integrate fzf into git
# https://github.com/junegunn/fzf-git.sh
###############################################################################
if [ ! -d ~/fzf-git.sh ]; then
  git clone git@github.com:junegunn/fzf-git.sh.git ~/fzf-git.sh
fi

###############################################################################
# Install git-delta
# https://github.com/dandavison/delta
###############################################################################
if ! is_package_installed "git-delta"; then
  brew install git-delta
  cp ./shell/git/gitconfig ~/.gitconfig
fi

###############################################################################
# Install tlrc (better version of man for command help docs)
# https://github.com/tldr-pages/tlrc
###############################################################################
brew install tlrc

###############################################################################
# Install thefuck
# https://github.com/nvbn/thefuck
###############################################################################
brew install thefuck

###############################################################################
# Install fnm (fast Node manager)
# https://github.com/Schniz/fnm
###############################################################################
brew install fnm

###############################################################################
# Install go
###############################################################################
brew install go

###############################################################################
# Install Claude Code (native installer)
# https://claude.ai/install.sh — installs the `claude` binary to ~/.local/bin.
# claude.zsh (sourced via load.zsh) puts ~/.local/bin on PATH. Idempotent: skip
# when claude is already installed/on PATH.
###############################################################################
if [ ! -x "$HOME/.local/bin/claude" ] && ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

###############################################################################
# Load all zsh configurations
###############################################################################
# Prepend the dotfiles source line ABOVE the Powerlevel10k instant-prompt
# block. p10k aborts instant prompt if any console I/O happens after its block
# runs, so anything that might print at init (warnings, deprecations, etc.)
# must run before it. Idempotent: skip if the line is already present.
SOURCE_LINE="source $(pwd)/shell/load.zsh"
if ! grep -qF "$SOURCE_LINE" ~/.zshrc; then
  { print -r -- "# Dotfiles modules — must precede Powerlevel10k instant prompt."
    print -r -- "$SOURCE_LINE"
    print
    cat ~/.zshrc
  } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
fi

###############################################################################
# Wire atuin AFTER oh-my-zsh. atuin is intentionally skipped by load.zsh's glob
# (see shell/load.zsh) because OMZ's `bindkey -e` would wipe atuin's ^R /
# up-arrow widgets off the emacs keymap if atuin loaded first. So source it just
# below `source $ZSH/oh-my-zsh.sh`. Idempotent: skip if the line is already
# present.
###############################################################################
ATUIN_LINE="source $(pwd)/shell/tools/atuin.zsh"
if ! grep -qF "$ATUIN_LINE" ~/.zshrc; then
  awk -v line="$ATUIN_LINE" '
    { print }
    /^source \$ZSH\/oh-my-zsh\.sh/ && !done {
      print ""
      print "# Dotfiles: atuin must load after oh-my-zsh (see shell/load.zsh)."
      print line
      done = 1
    }
  ' ~/.zshrc > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
fi

echo "✅ All configurations have been modularized and loaded!"