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
