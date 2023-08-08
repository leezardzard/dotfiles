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
fisher install jethrokuan/z
fisher install evanlucas/fish-kubectl-completions
fisher install edc/bass

###############################################################################
# Install brew packages for fish settings
###############################################################################
brew install exa
brew install peco