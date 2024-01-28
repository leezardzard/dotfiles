#!/bin/sh

###############################################################################
# Install zsh shell packages
###############################################################################
echo "Homebrew: installing shell packages..."
brew install zsh
sudo sh -c "echo $(which zsh) >> /etc/shells" 
sudo chsh -s $(which zsh) $(whoami)


###############################################################################
# Install oh my zsh packages
###############################################################################
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"


###############################################################################
# Install oh my zsh theme packages
###############################################################################
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
THEME="powerlevel10k\/powerlevel10k"; sed -i.bu s/^ZSH_THEME=\".*\"/ZSH_THEME=\"$THEME\"/ ~/.zshrc && source ~/.zshrc && echo "Edited line in ~/zshrc :" && cat ~/.zshrc | grep -m 1 ZSH_THEME
exec $SHELL