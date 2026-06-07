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
# Symlink ~/.p10k.zsh -> repo's .p10k.zsh so p10k config is tracked here.
# Back up any existing real file first; idempotent if the symlink already
# points at the right target.
###############################################################################
P10K_REPO="$(pwd)/.p10k.zsh"
if [ -e "$P10K_REPO" ]; then
  if [ -L ~/.p10k.zsh ] && [ "$(readlink ~/.p10k.zsh)" = "$P10K_REPO" ]; then
    echo "~/.p10k.zsh already linked to $P10K_REPO"
  else
    if [ -e ~/.p10k.zsh ] || [ -L ~/.p10k.zsh ]; then
      mv ~/.p10k.zsh ~/.p10k.zsh.backup-$(date +%Y%m%d-%H%M%S)
    fi
    ln -s "$P10K_REPO" ~/.p10k.zsh
    echo "Linked ~/.p10k.zsh -> $P10K_REPO"
  fi
fi

###############################################################################
# Symlink ~/.config/ghostty -> repo's .config/ghostty so Ghostty terminal
# settings (Morandi ANSI palette, etc.) are tracked here. Mirrors the same
# pattern as ~/.config/cmux. Idempotent; backs up any existing real directory.
###############################################################################
GHOSTTY_REPO="$(pwd)/.config/ghostty"
if [ -d "$GHOSTTY_REPO" ]; then
  mkdir -p ~/.config
  # Same-inode guard: if ~/.config/ghostty already resolves to $GHOSTTY_REPO it
  # needs no linking. This covers BOTH a direct ghostty symlink AND the case
  # where ~/.config itself is a symlink into the repo (~/.config -> .dotfiles/
  # .config) — there ~/.config/ghostty *is* $GHOSTTY_REPO, so the old code would
  # mv the repo's own source dir aside and `ln -s` the path to itself, producing
  # a self-referential loop ("Too many levels of symbolic links"). Skip instead.
  if [ ~/.config/ghostty -ef "$GHOSTTY_REPO" ]; then
    echo "~/.config/ghostty already resolves to $GHOSTTY_REPO"
  else
    if [ -e ~/.config/ghostty ] || [ -L ~/.config/ghostty ]; then
      mv ~/.config/ghostty ~/.config/ghostty.backup-$(date +%Y%m%d-%H%M%S)
    fi
    ln -s "$GHOSTTY_REPO" ~/.config/ghostty
    echo "Linked ~/.config/ghostty -> $GHOSTTY_REPO"
  fi
fi

###############################################################################
# Symlink ~/.claude/statusline-command.sh -> repo's scripts/claude/statusline-command.sh
# so the Claude Code status line is tracked here. Same idempotent pattern as
# the p10k/ghostty blocks. Then patch any settings.json that references the
# script so its statusLine command uses $HOME instead of a hardcoded absolute
# path — that makes it portable across devices (different usernames).
# Runtime deps: jq (Brewfile core) and ccusage via npx (Node/fnm).
###############################################################################
STATUSLINE_REPO="$(pwd)/scripts/claude/statusline-command.sh"
if [ -f "$STATUSLINE_REPO" ]; then
  mkdir -p ~/.claude
  if [ -L ~/.claude/statusline-command.sh ] && [ "$(readlink ~/.claude/statusline-command.sh)" = "$STATUSLINE_REPO" ]; then
    echo "~/.claude/statusline-command.sh already linked to $STATUSLINE_REPO"
  else
    if [ -e ~/.claude/statusline-command.sh ] || [ -L ~/.claude/statusline-command.sh ]; then
      mv ~/.claude/statusline-command.sh ~/.claude/statusline-command.sh.backup-$(date +%Y%m%d-%H%M%S)
    fi
    ln -s "$STATUSLINE_REPO" ~/.claude/statusline-command.sh
    echo "Linked ~/.claude/statusline-command.sh -> $STATUSLINE_REPO"
  fi

  # Point every settings.json (default config + each claude-switch profile) at
  # the portable "$HOME"-relative statusLine command. Three cases, idempotent:
  #   - no statusLine set       -> install {type: command, command: ...}
  #   - ours, hardcoded path    -> rewrite command to the portable form
  #   - a different custom one  -> leave it untouched
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
  cp ./scripts/zsh-config/git/gitconfig ~/.gitconfig
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
SOURCE_LINE="source $(pwd)/scripts/zsh-config/load.zsh"
if ! grep -qF "$SOURCE_LINE" ~/.zshrc; then
  { print -r -- "# Dotfiles modules — must precede Powerlevel10k instant prompt."
    print -r -- "$SOURCE_LINE"
    print
    cat ~/.zshrc
  } > ~/.zshrc.tmp && mv ~/.zshrc.tmp ~/.zshrc
fi

echo "✅ All configurations have been modularized and loaded!"