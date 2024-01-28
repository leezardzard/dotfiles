#!/path/to/fish

###############################################################################
# Install fish shell packages
###############################################################################
echo "Homebrew: installing shell packages..."
brew install fish
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

###############################################################################
# Install fish prompt theme
###############################################################################
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