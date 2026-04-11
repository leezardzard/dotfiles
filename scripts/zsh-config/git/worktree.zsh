###############################################################################
# Git Worktree Switcher using fzf
###############################################################################

# Resolve git path once so we work when PATH is minimal (e.g. Cursor terminal).
if [[ -n "${_WORKTREE_GIT:-}" && -x "$_WORKTREE_GIT" ]]; then
  : # already set
else
  _WORKTREE_GIT=$(command -v git 2>/dev/null)
  [[ -z "$_WORKTREE_GIT" && -x /usr/bin/git ]] && _WORKTREE_GIT=/usr/bin/git
  [[ -z "$_WORKTREE_GIT" && -x /opt/homebrew/bin/git ]] && _WORKTREE_GIT=/opt/homebrew/bin/git
fi
_worktree_git() {
  [[ -n "$_WORKTREE_GIT" && -x "$_WORKTREE_GIT" ]] || { echo "git not found" >&2; return 1 }
  "$_WORKTREE_GIT" "$@"
}

# Resolve fzf path once so we work when PATH is minimal (e.g. Cursor terminal).
if [[ -n "${_WORKTREE_FZF:-}" && -x "$_WORKTREE_FZF" ]]; then
  : # already set
else
  _WORKTREE_FZF=$(command -v fzf 2>/dev/null)
  [[ -z "$_WORKTREE_FZF" && -x /opt/homebrew/bin/fzf ]] && _WORKTREE_FZF=/opt/homebrew/bin/fzf
  [[ -z "$_WORKTREE_FZF" && -x /usr/local/bin/fzf ]] && _WORKTREE_FZF=/usr/local/bin/fzf
fi
_worktree_fzf() {
  [[ -n "$_WORKTREE_FZF" && -x "$_WORKTREE_FZF" ]] || { echo "fzf not found" >&2; return 1 }
  "$_WORKTREE_FZF" "$@"
}

# --- Worktree sync whitelist helpers ---
# Config file: .worktree-sync-whitelist at main worktree root (one path per line).
# Ignored files/dirs listed there are symlinked from new worktrees into main.

# _worktree_get_main_path: Print absolute path of worktree that has main or master checked out.
# Prints nothing if none. Must be run from inside the repo.
_worktree_get_main_path() {
  local wt_list
  wt_list=$(_worktree_git worktree list --porcelain 2>/dev/null) || return 1
  local current_path="" branch=""
  while IFS= read -r line; do
    if [[ "$line" == worktree* ]]; then
      current_path="${line#worktree }"
    elif [[ "$line" == branch* ]]; then
      branch="${line#branch refs/heads/}"
      if [[ "$branch" == "main" || "$branch" == "master" ]]; then
        current_path="${current_path%%[[:space:]]*}"
        echo "$current_path"
        return 0
      fi
    fi
  done <<< "$wt_list"
  return 0
}

# _worktree_branch_to_path_safe: Print branch name with / replaced by - for use in worktree directory paths.
_worktree_branch_to_path_safe() {
  echo "${1//\//-}"
}

# _worktree_default_branch: Print main or master, whichever exists (prefer main). Used as default parent for new branches.
_worktree_default_branch() {
  _worktree_git rev-parse --verify --quiet main >/dev/null 2>&1 && { echo main; return }
  _worktree_git rev-parse --verify --quiet master >/dev/null 2>&1 && { echo master; return }
  echo main
}

# _worktree_relative_path from_dir to_path -> relative path such that from_dir/result == to_path (conceptually).
_worktree_relative_path() {
  local from_dir="${1:A}" to_path="${2:A}"
  from_dir="${from_dir%/}"
  to_path="${to_path%/}"
  local from_parts=("${(s./.)from_dir}") to_parts=("${(s./.)to_path}")
  # Skip empty first element if present (from leading /)
  [[ -z "${from_parts[1]}" ]] && from_parts=("${from_parts[@]:1}")
  [[ -z "${to_parts[1]}" ]] && to_parts=("${to_parts[@]:1}")
  local i=1
  while [[ i -le $#from_parts && i -le $#to_parts && "${from_parts[$i]}" == "${to_parts[$i]}" ]]; do
    (( i++ ))
  done
  local up_count=$(( $#from_parts - i + 1 ))
  local rel=""
  for (( j = 0; j < up_count; j++ )); do rel+="../"; done
  for (( j = i; j <= $#to_parts; j++ )); do
    [[ -n "$rel" && "$rel" != */ ]] && rel+="/"
    rel+="${to_parts[$j]}"
  done
  echo "$rel"
}

# _worktree_sync_symlinks main_worktree_path new_worktree_path
# Reads .worktree-sync-whitelist from main; creates symlinks in new worktree for each path.
_worktree_sync_symlinks() {
  local main_path="$1" new_path="$2"
  local whitelist_file="$main_path/.worktree-sync-whitelist"
  [[ ! -f "$whitelist_file" ]] && return 0
  local path
  while IFS= read -r path || [[ -n "$path" ]]; do
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    path="${path%/}"
    [[ -z "$path" ]] && continue
    local target="$main_path/$path"
    local link_path="$new_path/$path"
    if [[ ! -e "$target" ]]; then
      echo "⚠️  Skip symlink (target missing): $path"
      continue
    fi
    if [[ -e "$link_path" ]]; then
      echo "⚠️  Skip symlink (already exists): $path"
      continue
    fi
    local link_parent="${link_path:h}"
    if [[ "$link_parent" != "." && "$link_parent" != "$new_path" ]]; then
      /bin/mkdir -p "$link_parent"
    fi
    local rel_target
    rel_target=$(_worktree_relative_path "$link_parent" "$target")
    if [[ -z "$rel_target" ]]; then
      rel_target="$target"
    fi
    /bin/ln -s "$rel_target" "$link_path" && echo "🔗 Linked: $path"
  done < "$whitelist_file"
}

# worktree_sync_whitelist_from_untracked: Initialize whitelist. List paths ignored by git (main worktree, git status --ignored),
# let user select via fzf, then write selection to .worktree-sync-whitelist.
# Steps: 1) Get ignored paths from git status --ignored --porcelain  2) Show in fzf  3) User selects  4) Create whitelist file.
worktree_sync_whitelist_from_untracked() {
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository."
    return 1
  fi
  local main_path
  main_path=$(_worktree_get_main_path)
  main_path="${main_path%%[[:space:]]*}"
  if [[ -z "$main_path" ]]; then
    echo "❌ Error: No worktree with main or master branch found."
    return 1
  fi
  # 1. Get ignored paths from main worktree. Use git -C and --no-pager so output is plain (no bat/less).
  local ignored_paths=() line path
  local raw_status git_stderr_file="/tmp/wt-git-err-$$"
  raw_status=$(GIT_PAGER= _worktree_git -C "$main_path" --no-pager status --ignored --porcelain 2>"$git_stderr_file")
  if [[ -z "$raw_status" && -s "$git_stderr_file" ]]; then
    echo "⚠️  git status in main worktree failed:" >&2
    print -r -u2 -- "$(< "$git_stderr_file")"
  fi
  [[ -f "$git_stderr_file" ]] && /usr/bin/rm -f "$git_stderr_file" 2>/dev/null
  while IFS= read -r line; do
    [[ "$line" != !!* ]] && continue
    path="${line#!! }"
    path="${path%\"}"
    path="${path#\"}"
    [[ -z "$path" ]] && continue
    ignored_paths+=("$path")
  done <<< "$raw_status"

  if [[ ${#ignored_paths[@]} -eq 0 ]]; then
    echo "No ignored files or directories in main worktree. Nothing to whitelist."
    return 0
  fi

  # 2. Show selection list via fzf.
  local selected
  selected=$(printf '%s\n' "${ignored_paths[@]}" | _worktree_fzf --multi --prompt="Select paths to sync to new worktrees> " \
    --header="TAB to select, ENTER to confirm. These will be symlinked from new worktrees (ignored paths).")

  if [[ -z "$selected" ]]; then
    echo "🔵 No paths selected."
    return 0
  fi

  # 3 & 4. User selection → create whitelist file.
  local whitelist_file="$main_path/.worktree-sync-whitelist"
  echo "$selected" > "$whitelist_file"
  echo "✅ Whitelist saved to $whitelist_file"
}

# worktree_sync_from_whitelist: Sync files from main worktree to current worktree using .worktree-sync-whitelist.
# Run from inside the worktree you want to sync to. Fails if run from main worktree or if whitelist is missing.
worktree_sync_from_whitelist() {
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository."
    return 1
  fi
  local main_path
  main_path=$(_worktree_get_main_path)
  if [[ -z "$main_path" ]]; then
    echo "❌ Error: No worktree with main or master branch found."
    return 1
  fi
  local target_path
  target_path=$(_worktree_git rev-parse --show-toplevel)
  if [[ "$target_path" == "$main_path" ]]; then
    echo "❌ Error: You are in the main worktree. Run 'wt sync' from the worktree you want to sync to."
    return 1
  fi
  local whitelist_file="$main_path/.worktree-sync-whitelist"
  if [[ ! -f "$whitelist_file" ]]; then
    echo "❌ No worktree sync whitelist found. Run 'wt wl' first to create one."
    return 1
  fi
  echo "Syncing from main worktree to $target_path..."
  _worktree_sync_symlinks "$main_path" "$target_path"
  echo "✅ Sync done."
}

# worktree_switch: Fzf-pick worktree from list, cd into it.
worktree_switch() {
  # Exit if not in a git repository.
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not in a git repository."
    return 1
  fi

  # Get the list of worktrees and display it with fzf for selection.
  local selected_worktree=$(_worktree_git worktree list | _worktree_fzf --prompt="Select Git Worktree> " | awk '{print $1}')

  # If a worktree was selected, cd into it.
  if [[ -n "$selected_worktree" ]]; then
    cd "$selected_worktree"
    echo "Switched to worktree: $selected_worktree"
    ls -a
  fi
}

# worktree_list: Browse worktrees in fzf with a preview pane (git status + recent commits
# for the highlighted worktree). View-only — use `wt go` to switch. Falls back to plain
# `git worktree list` when fzf is not installed.
worktree_list() {
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not in a git repository."
    return 1
  fi
  if [[ -n "$_WORKTREE_FZF" && -x "$_WORKTREE_FZF" ]]; then
    local preview_cmd="$_WORKTREE_GIT -C {1} --no-pager status -sb 2>/dev/null; echo; $_WORKTREE_GIT -C {1} --no-pager log --oneline --decorate -10 2>/dev/null"
    _worktree_git worktree list | _worktree_fzf --prompt="Worktrees> " \
      --header="View-only. ESC to exit. Use 'wt go' to switch." \
      --preview="$preview_cmd" \
      --preview-window=right:60%:wrap > /dev/null
  else
    _worktree_git worktree list
  fi
}

# worktree_add_remote_branch: Checkout an existing remote branch and create a worktree for it.
# Interactively selects a remote branch using fzf.
worktree_add_remote_branch() {
  # Exit if not in a git repository.
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository."
    return 1
  fi

  # Fetch remote branches to ensure we have the latest list.
  echo "🔄 Fetching remote branches..."
  _worktree_git fetch --all --quiet

  # Get the list of remote branches and display it with fzf for selection.
  # Remove 'origin/' prefix and filter out HEAD reference
  local selected_branch=$(_worktree_git branch -r | grep -v HEAD | sed 's|origin/||' | sed 's|^[[:space:]]*||' | _worktree_fzf --prompt="Select Remote Branch> " \
    --header="Select a remote branch to checkout into a new worktree")

  if [[ -z "$selected_branch" ]]; then
    echo "🔵 Operation cancelled."
    return 0
  fi

  # Remove any leading/trailing whitespace
  selected_branch=$(echo "$selected_branch" | xargs)

  # Check if a worktree for this branch already exists
  if _worktree_git worktree list | grep -q "\[$selected_branch\]"; then
    echo "⚠️  A worktree for branch '$selected_branch' already exists."
    local existing_path=$(_worktree_git worktree list | grep "\[$selected_branch\]" | awk '{print $1}')
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

  # Auto-detect paths and names (similar to worktree_add_branch)
  local repo_root=$(_worktree_git rev-parse --show-toplevel)
  local repo_name="${repo_root:t}"
  local repo_parent_dir="${repo_root:h}"
  local path_safe=$(_worktree_branch_to_path_safe "$selected_branch")
  local new_worktree_path="$repo_parent_dir/$repo_name-$path_safe"

  echo "🌿 Checking out remote branch '$selected_branch' to new worktree..."
  echo "   Path: $new_worktree_path"

  # Checkout the remote branch into a new worktree
  # First ensure the branch exists locally (tracking the remote branch)
  if ! _worktree_git rev-parse --verify --quiet "$selected_branch" > /dev/null 2>&1; then
    # Branch doesn't exist locally, create it tracking the remote
    _worktree_git worktree add "$new_worktree_path" -b "$selected_branch" "origin/$selected_branch"
  else
    # Branch exists locally, just checkout
    _worktree_git worktree add "$new_worktree_path" "$selected_branch"
  fi

  # Check if the operation was successful
  if [[ $? -eq 0 ]]; then
    echo "✅ Success! Worktree created for branch '$selected_branch'."
    local main_path
    main_path=$(_worktree_get_main_path)
    if [[ -n "$main_path" ]]; then
      local whitelist_file="$main_path/.worktree-sync-whitelist"
      if [[ ! -f "$whitelist_file" ]]; then
        printf "No worktree sync whitelist found. Create one now? (y/n): "
        read -r create_whitelist
        if [[ "$(echo "$create_whitelist" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
          worktree_sync_whitelist_from_untracked
          _worktree_sync_symlinks "$main_path" "$new_worktree_path"
        fi
      else
        _worktree_sync_symlinks "$main_path" "$new_worktree_path"
      fi
    fi
    echo "   Switching to: $new_worktree_path"
    cd "$new_worktree_path"
    ls -a
  else
    echo "⚠️  Operation failed. Please check the error messages."
    return 1
  fi
}

# worktree_add_branch: Create a new git worktree for a branch (create branch if it doesn't exist).
# Usage: worktree_add_branch [-p] <branch-name> [parent-branch]
# Default: create new branch from main (or master). Use -p to fzf-pick parent; or pass parent explicitly.
worktree_add_branch() {
  local prompt_parent=0
  [[ "$1" == -p ]] && { prompt_parent=1; shift }
  # --- 1. Argument Check ---
  if [[ -z "$1" ]]; then
    echo "❌ Error: Branch name is required."
    echo "Usage: worktree_add_branch [-p] <branch-name> [parent-branch]"
    return 1
  fi

  local branch_name="$1"
  local parent_branch="$2"

  # --- 2. Auto-detect Paths and Names ---
  # Get the absolute path of the Git repository's root directory.
  local repo_root=$(_worktree_git rev-parse --show-toplevel)
  if [[ -z "$repo_root" ]]; then
    # Cannot proceed if not inside a Git repository.
    return 1
  fi

  # Get the project folder name from the root path.
  local repo_name="${repo_root:t}"
  # Get the parent directory path of the project.
  local repo_parent_dir="${repo_root:h}"

  # Construct the full path for the new worktree (use path-safe branch name to avoid nested folders).
  local path_safe=$(_worktree_branch_to_path_safe "$branch_name")
  local new_worktree_path="$repo_parent_dir/$repo_name-$path_safe"

  # --- 3. Intelligently Decide and Execute ---
  # Check if the branch already exists and already has a worktree (one branch = one folder).
  if _worktree_git rev-parse --verify --quiet "$branch_name" > /dev/null; then
    local existing_path
    existing_path=$(_worktree_git worktree list | awk -v br="$branch_name" '$0 ~ "\\[" br "\\]" { print $1; exit }')
    if [[ -n "$existing_path" ]]; then
      echo "🌿 Branch '$branch_name' already has a worktree. Switching to it."
      cd "$existing_path"
      echo "✅ Switched to: $existing_path"
      return 0
    fi
    # Branch exists but no worktree (e.g. worktree was removed): create the single worktree for it.
    echo "Preparing to create a worktree at '$new_worktree_path'..."
    echo "🌿 Branch '$branch_name' already exists. Creating its worktree."
    _worktree_git worktree add "$new_worktree_path" "$branch_name"
  else
    # Branch does not exist: resolve parent (explicit arg, or -p fzf, or default main/master).
    echo "Preparing to create a worktree at '$new_worktree_path'..."
    if [[ -n "$parent_branch" ]]; then
      # Explicit parent given on command line.
      :
    elif [[ $prompt_parent -eq 1 ]]; then
      # -p: interactive pick parent via fzf (local branches).
      local branch_list
      branch_list=$(_worktree_git for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null | _worktree_fzf --prompt="Select parent branch for '$branch_name'> " \
        --header="Choose the branch or commit to create from. ENTER to confirm, ESC to cancel.")
      [[ -z "$branch_list" ]] && { echo "🔵 Operation cancelled."; return 0; }
      parent_branch="${branch_list%%[[:space:]]*}"
    else
      # Default: use main or master.
      parent_branch=$(_worktree_default_branch)
    fi
    if [[ -n "$parent_branch" ]]; then
      if ! _worktree_git rev-parse --verify --quiet "$parent_branch" > /dev/null 2>&1; then
        echo "❌ Error: Parent '$parent_branch' is not a valid branch or commit."
        return 1
      fi
      echo "✨ Creating new branch '$branch_name' from '$parent_branch' and setting up worktree."
      _worktree_git worktree add "$new_worktree_path" -b "$branch_name" "$parent_branch"
    else
      echo "✨ Creating new branch '$branch_name' and setting up worktree."
      _worktree_git worktree add "$new_worktree_path" -b "$branch_name"
    fi
  fi

  # --- 4. Provide Feedback on the Result ---
  # Check if the last command was successful.
  if [[ $? -eq 0 ]]; then
    echo "✅ Success! Worktree has been created."
    local main_path
    main_path=$(_worktree_get_main_path)
    if [[ -n "$main_path" ]]; then
      local whitelist_file="$main_path/.worktree-sync-whitelist"
      if [[ ! -f "$whitelist_file" ]]; then
        printf "No worktree sync whitelist found. Create one now? (y/n): "
        read -r create_whitelist
        if [[ "$(echo "$create_whitelist" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
          worktree_sync_whitelist_from_untracked
          _worktree_sync_symlinks "$main_path" "$new_worktree_path"
        fi
      else
        _worktree_sync_symlinks "$main_path" "$new_worktree_path"
      fi
    fi
    echo "   You can now switch to it using 'wt go' or 'cd $new_worktree_path'."
  else
    echo "⚠️ Operation failed. Please check the error messages."
  fi
}

# worktree_remove: Interactively select and safely REMOVE one or more git worktrees with confirmation.
# EXCLUDES main/master/dev/develop branches and the root worktree path from the list.
# Supports multi-select: TAB to toggle selection, ENTER to confirm.
# Pass -f / --force to run `git worktree remove --force` (removes dirty/locked worktrees).
worktree_remove() {
  local force=0
  while [[ "$1" == -* ]]; do
    case "$1" in
      -f|--force) force=1; shift ;;
      *) echo "Usage: wt rm [-f|--force]" >&2; return 1 ;;
    esac
  done

  # --- 1. Interactively Select the Worktree(s) to Remove ---
  local main_path
  main_path=$(_worktree_get_main_path)
  local fzf_prompt="SELECT WORKTREE(S) TO REMOVE> "
  local fzf_header="[WARNING] Main/dev and root worktree excluded. TAB to multi-select, ENTER to proceed."
  if (( force )); then
    fzf_prompt="SELECT WORKTREE(S) TO FORCE-REMOVE> "
    fzf_header="[FORCE] Will use --force. TAB to multi-select, ENTER to proceed."
  fi
  local selected_lines=$(_worktree_git worktree list | grep -vE '\[main\]|\[master\]|\[dev\]|\[develop\]' | awk -v main="$main_path" 'main == "" || $1 != main' | _worktree_fzf --multi --prompt="$fzf_prompt" \
    --header="$fzf_header")

  if [[ -z "$selected_lines" ]]; then
    echo "🔵 Operation cancelled."
    return 0
  fi

  # --- 2. Parse selection into parallel arrays and fool-proof against current worktree ---
  local current_worktree=$(_worktree_git rev-parse --show-toplevel)
  local -a paths=() branches=()
  local line path branch
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Use zsh parameter expansion (no awk) so this works in minimal-PATH shells.
    path="${line%% *}"
    branch="${line##* }"
    [[ -z "$path" ]] && continue
    if [[ "$path" == "$current_worktree" ]]; then
      echo "❌ Error: You cannot remove the worktree you are currently in."
      echo "   Path: $current_worktree"
      return 1
    fi
    paths+=("$path")
    branches+=("$branch")
  done <<< "$selected_lines"

  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "🔵 Operation cancelled."
    return 0
  fi

  # --- 3. Yes/No Confirmation Prompt ---
  echo ""
  echo "🔴🔴🔴 DANGER ZONE 🔴🔴🔴"
  if (( force )); then
    echo "You are about to FORCE-REMOVE ${#paths[@]} worktree(s) (--force, dirty changes will be lost):"
  else
    echo "You are about to PERMANENTLY REMOVE ${#paths[@]} worktree(s):"
  fi
  local i
  for (( i = 1; i <= ${#paths[@]}; i++ )); do
    echo "  - ${paths[$i]}  ${branches[$i]}"
  done
  echo ""

  printf "Type 'yes' to confirm this action: "
  read confirmation

  # --- 4. Execute or Cancel ---
  if [[ "${confirmation:l}" != "yes" ]]; then
    echo "🔵 Operation cancelled by user."
    return 0
  fi

  local -a removed=() failed=()
  echo "🔥 Removing worktree(s)..."
  for (( i = 1; i <= ${#paths[@]}; i++ )); do
    if (( force )); then
      if _worktree_git worktree remove --force "${paths[$i]}"; then
        removed+=("${paths[$i]} ${branches[$i]}")
      else
        failed+=("${paths[$i]} ${branches[$i]}")
      fi
    else
      if _worktree_git worktree remove "${paths[$i]}"; then
        removed+=("${paths[$i]} ${branches[$i]}")
      else
        failed+=("${paths[$i]} ${branches[$i]}")
      fi
    fi
  done

  echo "✅ Removed ${#removed[@]} worktree(s)."
  if (( ${#failed[@]} > 0 )); then
    echo "⚠️  Failed: ${#failed[@]}"
    printf '   - %s\n' "${failed[@]}"
    if (( force )); then
      echo "   Even --force failed — check if the worktree is locked ('git worktree unlock <path>')."
    else
      echo "   Retry with 'wt rm -f' to force-remove (dirty changes will be lost)."
    fi
    return 1
  fi
}

# worktree_help: Print usage and subcommand descriptions for wt.
worktree_help() {
  cat <<'EOF'
wt - Git worktree switcher (fzf)

Usage: wt <subcommand> [args]

Subcommands:
  add [-p] <branch> [parent]  Add a worktree for a branch. New branch defaults to main/master; use -p to fzf-pick parent.
  remote                     Fzf-pick a remote branch and add a worktree for it.
  go                         Fzf-pick a worktree and cd into it.
  ls                         Browse worktrees in fzf with a status/log preview (view-only). Plain list if fzf missing.
  wl                         Initialize whitelist: fzf-pick ignored paths from main worktree, write to .worktree-sync-whitelist.
  sync                       Sync files from main to current worktree using .worktree-sync-whitelist.
  rm [-f|--force]            Fzf-pick (TAB for multi-select, main/dev excluded) and remove after confirmation. -f to force.
  help                       Show this help.

Examples:
  wt add feature-x
  wt add -p feature-x
  wt add feature-x develop
  wt remote
  wt go
  wt ls
  wt rm
EOF
}

# --- wt: single entry point with short subcommands ---
# Usage: wt add [-p] <branch> [parent] | remote | go | ls | wl | sync | rm | help
wt() {
  if [[ -z "$1" ]]; then
    worktree_help
    return 0
  fi
  local cmd="$1"
  shift
  case "$cmd" in
    add)    worktree_add_branch "$@" ;;
    remote) worktree_add_remote_branch "$@" ;;
    go)     worktree_switch "$@" ;;
    ls)     worktree_list "$@" ;;
    wl)     worktree_sync_whitelist_from_untracked "$@" ;;
    sync)   worktree_sync_from_whitelist "$@" ;;
    rm)     worktree_remove "$@" ;;
    help|-h|--help) worktree_help ;;
    *)      echo "Usage: wt add [-p] <branch> [parent] | remote | go | ls | wl | sync | rm | help" >&2; return 1 ;;
  esac
} 