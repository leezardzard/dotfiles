#!/path/to/fish

###############################################################################
# Install fish prompt theme
###############################################################################
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
fisher install IlanCosman/tide@v5

###############################################################################
# Install packages
###############################################################################
fisher install jorgebucaran/nvm.fish
fisher install jethrokuan/z
fisher install evanlucas/fish-kubectl-completions

###############################################################################
# Install brew packages for fish settings
###############################################################################
brew install exa
brew install peco