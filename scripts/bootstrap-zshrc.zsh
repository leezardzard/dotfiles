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
  if [ -L ~/.config/ghostty ] && [ "$(readlink ~/.config/ghostty)" = "$GHOSTTY_REPO" ]; then
    echo "~/.config/ghostty already linked to $GHOSTTY_REPO"
  else
    if [ -e ~/.config/ghostty ] || [ -L ~/.config/ghostty ]; then
      mv ~/.config/ghostty ~/.config/ghostty.backup-$(date +%Y%m%d-%H%M%S)
    fi
    ln -s "$GHOSTTY_REPO" ~/.config/ghostty
    echo "Linked ~/.config/ghostty -> $GHOSTTY_REPO"
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