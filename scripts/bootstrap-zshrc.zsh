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
# Install Node relative packages
###############################################################################
brew install nvm
mkdir ~/.nvm

###############################################################################
# Install go
###############################################################################
brew install go

###############################################################################
# Load all zsh configurations
###############################################################################
# Ensure .zshrc ends with a newline before adding our source line
echo "" >> ~/.zshrc
echo "source $(pwd)/scripts/zsh-config/load.zsh" >> ~/.zshrc

echo "✅ All configurations have been modularized and loaded!"