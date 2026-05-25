###############################################################################
# cmux pane-layout quick-commands
###############################################################################

# Resolve cmux binary once so we work when PATH is minimal (e.g. Cursor terminal).
if [[ -n "${_CMUX_BIN:-}" && -x "$_CMUX_BIN" ]]; then
  : # already set
else
  _CMUX_BIN=$(command -v cmux 2>/dev/null)
  [[ -z "$_CMUX_BIN" && -x /opt/homebrew/bin/cmux ]] && _CMUX_BIN=/opt/homebrew/bin/cmux
  [[ -z "$_CMUX_BIN" && -x /usr/local/bin/cmux    ]] && _CMUX_BIN=/usr/local/bin/cmux
fi

_cmux_bin() {
  [[ -n "$_CMUX_BIN" && -x "$_CMUX_BIN" ]] || { echo "cmux not found" >&2; return 1; }
  "$_CMUX_BIN" "$@"
}

# _cmux_layout_json <n> — emit the layout JSON for n panes.
_cmux_layout_json() {
  local n=$1
  case "$n" in
    2)
      printf '%s' '{"direction":"horizontal","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]}'
      ;;
    3)
      printf '%s' '{"direction":"horizontal","split":0.5,"children":[{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]},{"pane":{"surfaces":[{"type":"terminal"}]}}]}'
      ;;
    4)
      printf '%s' '{"direction":"horizontal","split":0.5,"children":[{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]},{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]}]}'
      ;;
    5)
      printf '%s' '{"direction":"horizontal","split":0.6,"children":[{"direction":"horizontal","split":0.5,"children":[{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]},{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]}]},{"pane":{"surfaces":[{"type":"terminal"}]}}]}'
      ;;
    6)
      printf '%s' '{"direction":"horizontal","split":0.5,"children":[{"direction":"vertical","split":0.3333,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]}]},{"direction":"vertical","split":0.3333,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"direction":"vertical","split":0.5,"children":[{"pane":{"surfaces":[{"type":"terminal"}]}},{"pane":{"surfaces":[{"type":"terminal"}]}}]}]}]}'
      ;;
  esac
}

# _cmux_workspace_name <target>
# Echo "<repo>:<branch>" if target is inside a git repo, else basename of target.
# Repo name = basename of the main worktree (parent of git common dir).
_cmux_workspace_name() {
  local target=$1 toplevel common_dir main_wt repo branch
  if ! toplevel=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null); then
    print -r -- "${target:t}"
    return
  fi
  common_dir=$(git -C "$target" rev-parse --git-common-dir 2>/dev/null)
  [[ "$common_dir" != /* ]] && common_dir="$toplevel/$common_dir"
  main_wt=${${common_dir:A}:h}
  repo=${main_wt:t}
  branch=$(git -C "$target" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
    print -r -- "$repo"
  else
    print -r -- "$repo:$branch"
  fi
}

# cm-cd [path] <2|3|4|5|6>
#
# Open a new cmux workspace with a predefined split layout.
# Path defaults to $PWD; literal paths are tried first, then `zoxide query`.
# Workspace is named "<repo>:<branch>" (description = basename of target) if
# target is inside a git repo; otherwise named after the directory basename.
#
# Examples:
#   cm-cd ~/.dotfiles 4   # 2x2 grid in ~/.dotfiles
#   cm-cd dotf 3          # zoxide fuzzy match -> ~/.dotfiles
#   cm-cd 2               # side-by-side in $PWD
cm-cd() {
  local target n
  case $# in
    1) target=$PWD; n=$1 ;;
    2) target=$1;   n=$2 ;;
    *) echo "usage: cm-cd [path] <2|3|4|5|6>" >&2; return 2 ;;
  esac

  if [[ ! "$n" =~ ^[2-6]$ ]]; then
    echo "usage: cm-cd [path] <2|3|4|5|6>" >&2
    return 2
  fi

  # Resolve target: try literal path first (with ~ expansion + realpath),
  # then fall back to `zoxide query` so `cm-cd dotf 4` finds ~/.dotfiles.
  local expanded="${~target}"
  local resolved=${expanded:A}
  if [[ -d "$resolved" ]]; then
    target="$resolved"
  elif command -v zoxide >/dev/null 2>&1 && \
       resolved=$(zoxide query -- "$target" 2>/dev/null) && \
       [[ -d "$resolved" ]]; then
    target="$resolved"
  else
    echo "cm-cd: not a directory: $target" >&2
    return 2
  fi

  local ws_name layout
  ws_name=$(_cmux_workspace_name "$target")
  layout=$(_cmux_layout_json "$n")

  # If we're invoked from a single-pane cmux workspace (typical "fresh tab"
  # starter), close that workspace after spawning the new one so it doesn't
  # accumulate. Multi-pane workspaces are left alone — they likely hold work.
  local caller_ws=${CMUX_WORKSPACE_ID:-}
  local caller_panes=0
  if [[ -n "$caller_ws" ]]; then
    caller_panes=$(_cmux_bin list-panes --workspace "$caller_ws" 2>/dev/null | wc -l | tr -d ' ')
  fi

  local -a args=(new-workspace
    --name "$ws_name"
    --description "${target:t}"
    --cwd "$target"
    --layout "$layout"
    --focus true
  )
  # Discard stdout (`OK workspace:N`); errors still surface via stderr.
  _cmux_bin "${args[@]}" >/dev/null

  # Close the caller workspace AFTER focus has moved to the new one.
  # Background + disown so this shell isn't killed mid-function.
  if [[ -n "$caller_ws" && "$caller_panes" == "1" ]]; then
    ( _cmux_bin close-workspace --workspace "$caller_ws" >/dev/null 2>&1 ) &
    disown 2>/dev/null
  fi
}

# cm-wt-go
#
# Fzf-pick a git worktree and broadcast `cd <path>` to every terminal surface
# in the current cmux workspace. Local shell cd's first; broadcast follows.
# When not running inside a cmux workspace (no panes found), the local cd
# still happens and the broadcast is skipped with a notice.
cm-wt-go() {
  if ! _worktree_git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not in a git repository."
    return 1
  fi

  local selected_worktree
  selected_worktree=$(_worktree_git worktree list \
    | _worktree_fzf --prompt="Select Git Worktree (broadcast cd to all panes)> " \
    | awk '{print $1}')

  [[ -z "$selected_worktree" ]] && return 0

  if ! cd "$selected_worktree"; then
    echo "cm-wt-go: failed to cd into $selected_worktree" >&2
    return 1
  fi

  local broadcaster
  broadcaster=$(command -v cmux-cd-all 2>/dev/null)
  [[ -z "$broadcaster" && -x "$HOME/.dotfiles/bin/cmux-cd-all" ]] && \
    broadcaster="$HOME/.dotfiles/bin/cmux-cd-all"

  if [[ -z "$broadcaster" ]]; then
    echo "cm-wt-go: cmux-cd-all not found — local cd only" >&2
  else
    if "$broadcaster" "$selected_worktree" 2>/dev/null; then
      # Broadcast succeeded → we're in a cmux workspace. Rename it to match
      # the new worktree (e.g. ".dotfiles:main" → ".dotfiles:feature-x").
      local new_ws_name
      new_ws_name=$(_cmux_workspace_name "$selected_worktree")
      if [[ -n "$new_ws_name" ]]; then
        _cmux_bin rename-workspace "$new_ws_name" >/dev/null 2>&1 || true
      fi
    else
      echo "cm-wt-go: not in a cmux workspace — local cd only" >&2
    fi
  fi

  echo "Switched to worktree: $selected_worktree"
  ls -a
}
