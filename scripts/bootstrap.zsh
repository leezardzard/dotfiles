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
THEME="powerlevel10k\/powerlevel10k"
sed -i.bu s/^ZSH_THEME=\".*\"/ZSH_THEME=\"$THEME\"/ ~/.zshrc && source ~/.zshrc && echo "Edited line in ~/zshrc :" && cat ~/.zshrc | grep -m 1 ZSH_THEME
exec $SHELL

###############################################################################
# Install zsh plugins
###############################################################################
brew install zsh-autosuggestions
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

###############################################################################
# Fix zsh key binding issues
###############################################################################
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup bindkey
###############################################################################
bindkey "[D" backward-word
bindkey "[C" forward-word
EOT

###############################################################################
# Install bat (better version of cat)
###############################################################################
brew install bat
mkdir -p "$(bat --config-dir)/themes"
cd "$(bat --config-dir)/themes" &&
  curl -O https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme &&
  bat cache --build &&
  cd -
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup bat theme 
###############################################################################
export BAT_THEME=tokyonight_night
alias cat="bat"
EOT

###############################################################################
# Install zoxide (cache the visited path)
# https://github.com/ajeetdsouza/zoxide
###############################################################################
brew install zoxide
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup zoxide and alias
###############################################################################
eval "$(zoxide init zsh)"
alias cd="z"
EOT

###############################################################################
# Install eza (better version of ls)
# https://github.com/eza-community/eza
###############################################################################
brew install eza
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup eza alias 
###############################################################################
alias ls="eza --icons=always"
EOT

###############################################################################
# Install fzf
###############################################################################
brew install fzf
cat <<'EOT' >>~/.zshrc

###############################################################################
# fzf setup
# https://github.com/junegunn/fzf
###############################################################################
eval "$(fzf --zsh)"

###############################################################################
# fzf theme setup
# https://vitormv.github.io/fzf-themes/
###############################################################################
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"
EOT

###############################################################################
# Install fd to instead of fzf
# https://github.com/sharkdp/fd
###############################################################################
brew install fd
cat <<'EOT' >>~/.zshrc

###############################################################################
# Use fd instead of fzf
###############################################################################
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type=d --hidden --exclude .git . "$1"
}
EOT

###############################################################################
# Integrate fzf into git
# https://github.com/junegunn/fzf-git.sh
###############################################################################
git clone git@github.com:junegunn/fzf-git.sh.git ~/fzf-git.sh
cat <<'EOT' >>~/.zshrc

###############################################################################
# Integrate fzf into git
###############################################################################
source ~/fzf-git.sh/fzf-git.sh
EOT

###############################################################################
# Integrate eza and bat into fzf
###############################################################################
cat <<'EOT' >>~/.zshrc

###############################################################################
# Integrate eza and bat into fzf
###############################################################################
show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
  cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
  export | unset) fzf --preview "eval 'echo \${}'" "$@" ;;
  ssh) fzf --preview 'dig {}' "$@" ;;
  *) fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
EOT

###############################################################################
# Install git-delta
# https://github.com/dandavison/delta
###############################################################################
brew install git-delta
cat <<'EOT' >>~/.gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true    # use n and N to move between diff sections
    side-by-side = true 

    # delta detects terminal colors automatically; set one of these to disable auto-detection
    # dark = true
    # light = true

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
EOT

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
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup thefuck and alias
###############################################################################
eval $(thefuck --alias)
eval $(thefuck --alias fk)
EOT

###############################################################################
# Install go
###############################################################################
brew install go

cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup go
###############################################################################
export GOPATH=\$HOME/golang
export GOROOT=/opt/homebrew/opt/go/libexec
export PATH=\$PATH:\$GOPATH/bin
export PATH=\$PATH:\$GOROOT/bin
EOT

###############################################################################
# Add FFMPEG function
###############################################################################
cat <<'EOT' >>~/.zshrc

###############################################################################
# Add FFMPEG function
###############################################################################
compress_video() {
    local source_file=$1
    local destination_file=$2

    ffmpeg -i "$source_file" -vcodec libx264 -preset fast -crf 20 -y -vf "scale=1920:-1" -acodec libmp3lame -ab 128k "$destination_file"
}
EOT
