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

# cgwt: Checkout an existing remote branch and create a worktree for it.
# Interactively selects a remote branch using fzf.
cgwt() {
  # Exit if not in a git repository.
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository."
    return 1
  fi

  # Fetch remote branches to ensure we have the latest list.
  echo "🔄 Fetching remote branches..."
  git fetch --all --quiet

  # Get the list of remote branches and display it with fzf for selection.
  # Remove 'origin/' prefix and filter out HEAD reference
  local selected_branch=$(git branch -r | grep -v HEAD | sed 's|origin/||' | sed 's|^[[:space:]]*||' | fzf --prompt="Select Remote Branch> " \
    --header="Select a remote branch to checkout into a new worktree")

  if [[ -z "$selected_branch" ]]; then
    echo "🔵 Operation cancelled."
    return 0
  fi

  # Remove any leading/trailing whitespace
  selected_branch=$(echo "$selected_branch" | xargs)

  # Check if a worktree for this branch already exists
  if git worktree list | grep -q "\[$selected_branch\]"; then
    echo "⚠️  A worktree for branch '$selected_branch' already exists."
    local existing_path=$(git worktree list | grep "\[$selected_branch\]" | awk '{print $1}')
    echo "   Path: $existing_path"
    printf "   Switch to it? (y/n): "
    read switch_confirm
    if [[ "$(echo "$switch_confirm" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
      cd "$existing_path"
      echo "✅ Switched to existing worktree: $existing_path"
      ls -a
    fi
    return 0
  fi

  # Auto-detect paths and names (similar to cgwt)
  local repo_root=$(git rev-parse --show-toplevel)
  local repo_name=$(basename "$repo_root")
  local repo_parent_dir=$(dirname "$repo_root")
  local new_worktree_path="$repo_parent_dir/$repo_name-$selected_branch"

  echo "🌿 Checking out remote branch '$selected_branch' to new worktree..."
  echo "   Path: $new_worktree_path"

  # Checkout the remote branch into a new worktree
  # First ensure the branch exists locally (tracking the remote branch)
  if ! git rev-parse --verify --quiet "$selected_branch" > /dev/null 2>&1; then
    # Branch doesn't exist locally, create it tracking the remote
    git worktree add "$new_worktree_path" -b "$selected_branch" "origin/$selected_branch"
  else
    # Branch exists locally, just checkout
    git worktree add "$new_worktree_path" "$selected_branch"
  fi

  # Check if the operation was successful
  if [[ $? -eq 0 ]]; then
    echo "✅ Success! Worktree created for branch '$selected_branch'."
    echo "   Switching to: $new_worktree_path"
    cd "$new_worktree_path"
    ls -a
  else
    echo "⚠️  Operation failed. Please check the error messages."
    return 1
  fi
}

# cngwt: Create a new git worktree intelligently.
# Usage: cgwt <branch-name>
cngwt() {
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
    echo "   You can now switch to it using 'fgwt' or 'cd $new_worktree_path'."
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
  echo "������ DANGER ZONE 🔴��🔴"
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