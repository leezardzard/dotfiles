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
# Install dust (better version of df)
# https://github.com/bootandy/dust
# ###############################################################################
brew install dust
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup dust alias 
###############################################################################
alias df="dust"
EOT

###############################################################################
# Install atuin (better version of history)
# https://github.com/atuinsh/atuin
###############################################################################
brew install atuin

cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup atuin alias 
###############################################################################
eval "$(atuin init zsh)"
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
if [ ! -d ~/fzf-git.sh ]; then
  git clone git@github.com:junegunn/fzf-git.sh.git ~/fzf-git.sh
  cat <<'EOT' >>~/.zshrc

###############################################################################
# Integrate fzf into git
###############################################################################
source ~/fzf-git.sh/fzf-git.sh
EOT
fi

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

if ! is_package_installed "git-delta"; then
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
cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup thefuck and alias
###############################################################################
eval $(thefuck --alias)
eval $(thefuck --alias fk)
EOT

###############################################################################
# Install Node relative packages
###############################################################################
brew install nvm
mkdir ~/.nvm

cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup nvm
###############################################################################
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

EOT

###############################################################################
# Install go
###############################################################################
brew install go

cat <<'EOT' >>~/.zshrc

###############################################################################
# Setup go
###############################################################################
export GOPATH=$HOME/golang
export GOROOT=/opt/homebrew/opt/go/libexec
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$GOROOT/bin
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

    ffmpeg -i "$source_file" -vcodec libx264 -preset fast -crf 20 -y -vf "scale=1920:trunc(ow/a/2)*2" -acodec libmp3lame -ab 128k "$destination_file"
}
EOT


###############################################################################
# Git Worktree Switcher using fzf
###############################################################################
cat <<'EOT' >>~/.zshrc

###############################################################################
# Git Worktree Switcher using fzf
###############################################################################
fgwt() {
  # Exit if not in a git repository.
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not in a git repository."
    return 1
  fi

  # Get the list of worktrees and display it with fzf for selection.
  local selected_worktree=$(git worktree list | fzf --prompt="Select Git Worktree> " | awk '{print $1}')

  # If a worktree was selected, cd into it.
  if [[ -n "$selected_worktree" ]]; then
    cd "$selected_worktree"
    echo "Switched to worktree: $selected_worktree"
    ls -a
  fi
}

# cgwt: Create a new git worktree intelligently.
# Usage: cgwt <branch-name>
cgwt() {
  # --- 1. Argument Check ---
  # Ensure the user has provided a branch name.
  if [[ -z "$1" ]]; then
    echo "❌ Error: Branch name is required."
    echo "Usage: cgwt <branch-name>"
    return 1
  fi

  local branch_name="$1"

  # --- 2. Auto-detect Paths and Names ---
  # Get the absolute path of the Git repository's root directory.
  local repo_root=$(git rev-parse --show-toplevel)
  if [[ -z "$repo_root" ]]; then
    # Cannot proceed if not inside a Git repository.
    return 1
  fi

  # Get the project folder name from the root path.
  local repo_name=$(basename "$repo_root")
  # Get the parent directory path of the project.
  local repo_parent_dir=$(dirname "$repo_root")

  # Construct the full path for the new worktree.
  local new_worktree_path="$repo_parent_dir/$repo_name-$branch_name"

  # --- 3. Intelligently Decide and Execute ---
  echo "Preparing to create a worktree at '$new_worktree_path'..."

  # Check if the branch already exists.
  if git rev-parse --verify --quiet "$branch_name" > /dev/null; then
    # Branch already exists, so just check it out into the new worktree.
    echo "🌿 Branch '$branch_name' already exists. Checking it out to the new worktree."
    git worktree add "$new_worktree_path" "$branch_name"
  else
    # Branch does not exist, so create it and set up the worktree.
    echo "✨ Creating new branch '$branch_name' and setting up worktree."
    git worktree add "$new_worktree_path" -b "$branch_name"
  fi

  # --- 4. Provide Feedback on the Result ---
  # Check if the last command was successful.
  if [[ $? -eq 0 ]]; then
    echo "✅ Success! Worktree has been created."
    echo "   You can now switch to it using 'gwt' or 'cd $new_worktree_path'."
  else
    echo "⚠️ Operation failed. Please check the error messages."
  fi
}

# rgwt: Interactively select and safely REMOVE a git worktree with confirmation.
# EXCLUDES 'main', 'master', 'dev', and 'develop' branches from the list.
rgwt() {
  # --- 1. Interactively Select the Worktree to Remove ---
  # Use grep -v to filter out main, master, dev, and develop branches before piping to fzf.
  local selected_line=$(git worktree list | grep -vE '\[main\]|\[master\]|\[dev\]|\[develop\]' | fzf --prompt="SELECT WORKTREE TO REMOVE> " \
    --header="[WARNING] Main/dev branches excluded. Use UP/DOWN to select, ENTER to proceed.")

  if [[ -z "$selected_line" ]]; then
    echo "🔵 Operation cancelled."
    return 0
  fi

  local worktree_to_remove=$(echo "$selected_line" | awk '{print $1}')
  local branch_name=$(echo "$selected_line" | awk '{print $2}')

  # --- 2. Core Fool-proofing Mechanism ---
  local current_worktree=$(git rev-parse --show-toplevel)
  if [[ "$worktree_to_remove" == "$current_worktree" ]]; then
    echo "❌ Error: You cannot remove the worktree you are currently in."
    echo "   Path: $current_worktree"
    return 1
  fi

  # --- 3. Yes/No Confirmation Prompt ---
  echo ""
  echo "🔴🔴🔴 DANGER ZONE 🔴🔴🔴"
  echo "You are about to PERMANENTLY REMOVE the following worktree:"
  echo "  - Path:   $worktree_to_remove"
  echo "  - Branch: $branch_name"
  echo ""

  printf "Type 'yes' to confirm this action: "
  read confirmation

  # --- 4. Execute or Cancel ---
  if [[ "$(echo "$confirmation" | tr '[:upper:]' '[:lower:]')" == "yes" ]]; then
    echo "🔥 Removing worktree..."
    git worktree remove "$worktree_to_remove"

    if [[ $? -eq 0 ]]; then
      echo "✅ Worktree successfully removed."
    else
      echo "⚠️ Removal failed. The worktree might contain unsaved changes."
      echo "   Try running 'git worktree remove --force $worktree_to_remove' manually if you are sure."
    fi
  else
    echo "🔵 Operation cancelled by user."
  fi
}

EOT