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

# Named colors accepted by `cmux workspace-action --action set-color`.
typeset -ga _CMUX_COLORS=(Red Crimson Orange Amber Olive Green Teal Aqua Blue Navy Indigo Purple Magenta Rose Brown Charcoal)

# _cmux_hash_index <string> — print 0..15 derived from md5 of <string>.
_cmux_hash_index() {
  local hex=""
  if command -v md5 >/dev/null 2>&1; then
    hex=$(print -n -- "$1" | md5 -q 2>/dev/null) || hex=""
  fi
  if [[ -z "$hex" ]] && command -v md5sum >/dev/null 2>&1; then
    hex=$(print -n -- "$1" | md5sum 2>/dev/null | cut -c1-8)
  fi
  if [[ -z "$hex" ]] && command -v cksum >/dev/null 2>&1; then
    hex=$(print -n -- "$1" | cksum | awk '{printf "%08x", $1}')
  fi
  [[ -z "$hex" ]] && { printf '0\n'; return; }
  printf '%d\n' $((16#${hex:0:1}))
}

# Persisted repo→color map. Guarantees uniqueness up to 16 active repos by
# tracking assignments in ~/.config/cmux/colors.json. On miss, pick the first
# palette color not currently in use (hash tiebreak); when all 16 are taken,
# evict the least-recently-used entry and reuse its color. Hash-only path
# (current behavior) is the graceful fallback when the file/lock is unusable.
typeset -gA _cmux_color_by_path _cmux_color_lastused_by_path

_cmux_color_state_file() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}/cmux/colors.json"
}

_cmux_color_lock_dir() {
  print -r -- "${XDG_CONFIG_HOME:-$HOME/.config}/cmux/colors.lock"
}

_cmux_color_log() {
  [[ -n "${CMUX_COLOR_DEBUG:-}" ]] && print -r -- "cm color: $*" >&2
}

# Acquire mkdir-based mutex with 2s budget; recover stale locks older than 5s.
_cmux_color_lock() {
  local lock dir age now mtime
  lock=$(_cmux_color_lock_dir)
  dir=${lock:h}
  mkdir -p "$dir" 2>/dev/null || return 1
  local i=0
  while ! mkdir "$lock" 2>/dev/null; do
    if [[ -d "$lock" ]]; then
      mtime=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo 0)
      now=$(date +%s)
      age=$(( now - mtime ))
      if (( age > 5 )); then
        rmdir "$lock" 2>/dev/null
        continue
      fi
    fi
    (( i++ >= 40 )) && return 1
    sleep 0.05
  done
  return 0
}

_cmux_color_unlock() {
  rmdir "$(_cmux_color_lock_dir)" 2>/dev/null
}

# Parse the on-disk JSON into _cmux_color_by_path / _cmux_color_lastused_by_path.
# Format we emit (and only format we parse) — one entry per line:
#     "<path>": {"color": "Red", "last_used": 1716700000}
# Malformed file → silently treated as empty (will be overwritten on next write).
_cmux_color_read_map() {
  _cmux_color_by_path=()
  _cmux_color_lastused_by_path=()
  local file line
  file=$(_cmux_color_state_file)
  [[ -f "$file" ]] || return 0
  while IFS= read -r line; do
    if [[ "$line" =~ '^[[:space:]]*"([^"]+)"[[:space:]]*:[[:space:]]*\{"color":[[:space:]]*"([A-Za-z]+)",[[:space:]]*"last_used":[[:space:]]*([0-9]+)\}' ]]; then
      _cmux_color_by_path[${match[1]}]=${match[2]}
      _cmux_color_lastused_by_path[${match[1]}]=${match[3]}
    fi
  done < "$file"
}

# Serialize the in-memory map to disk via tmp + atomic rename.
_cmux_color_write_map() {
  local file dir tmp paths p sep i n
  file=$(_cmux_color_state_file)
  dir=${file:h}
  mkdir -p "$dir" 2>/dev/null || return 1
  tmp="$file.tmp.$$"
  paths=(${(ko)_cmux_color_by_path})
  n=${#paths}
  {
    print -r -- "{"
    print -r -- '  "version": 1,'
    print -r -- '  "assignments": {'
    for (( i=1; i<=n; i++ )); do
      p=${paths[i]}
      sep=","
      (( i == n )) && sep=""
      print -r -- "    \"$p\": {\"color\": \"${_cmux_color_by_path[$p]}\", \"last_used\": ${_cmux_color_lastused_by_path[$p]}}$sep"
    done
    print -r -- "  }"
    print -r -- "}"
  } > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$file" 2>/dev/null || { rm -f "$tmp"; return 1; }
  return 0
}

# Resolve a stable color for <main_wt>, using the persisted map.
# On success: prints the color name and returns 0.
# On lock/write failure: returns 1 so caller can fall back to hash-only path.
_cmux_color_assign() {
  local key=$1
  if ! _cmux_color_lock; then
    _cmux_color_log "lock unavailable for $key"
    return 1
  fi
  {
    _cmux_color_read_map
    local now existing chosen p c h lru_path lru_ts ts
    now=$(date +%s)
    if [[ -n "${_cmux_color_by_path[$key]:-}" ]]; then
      existing=${_cmux_color_by_path[$key]}
      _cmux_color_lastused_by_path[$key]=$now
      _cmux_color_write_map
      _cmux_color_log "hit $key → $existing"
      print -r -- "$existing"
      return 0
    fi
    local -A in_use
    for p in ${(k)_cmux_color_by_path}; do
      in_use[${_cmux_color_by_path[$p]}]=1
    done
    local -a free
    for c in $_CMUX_COLORS; do
      [[ -z "${in_use[$c]:-}" ]] && free+=$c
    done
    if (( ${#free} > 0 )); then
      h=$(_cmux_hash_index "$key")
      chosen=${free[$(( h % ${#free} + 1 ))]}
      _cmux_color_log "miss $key → $chosen (free=${#free}/16)"
    else
      lru_ts=""
      for p in ${(k)_cmux_color_by_path}; do
        ts=${_cmux_color_lastused_by_path[$p]}
        if [[ -z "$lru_ts" || $ts -lt $lru_ts ]]; then
          lru_ts=$ts
          lru_path=$p
        fi
      done
      chosen=${_cmux_color_by_path[$lru_path]}
      unset "_cmux_color_by_path[$lru_path]"
      unset "_cmux_color_lastused_by_path[$lru_path]"
      _cmux_color_log "evict $lru_path → reusing $chosen for $key"
    fi
    _cmux_color_by_path[$key]=$chosen
    _cmux_color_lastused_by_path[$key]=$now
    _cmux_color_write_map
    print -r -- "$chosen"
  } always {
    _cmux_color_unlock
  }
}

# _cmux_color_for_target <target> — print a palette color name. Always succeeds.
# Stable per repo (keyed by main-worktree path) when the persisted map is
# writable; falls back to hash-only (today's behavior) on any I/O failure;
# random for non-git targets.
_cmux_color_for_target() {
  local target=$1 toplevel common_dir main_wt idx color
  if toplevel=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null); then
    common_dir=$(git -C "$target" rev-parse --git-common-dir 2>/dev/null)
    [[ "$common_dir" != /* ]] && common_dir="$toplevel/$common_dir"
    main_wt=${${common_dir:A}:h}
    if color=$(_cmux_color_assign "$main_wt"); then
      print -r -- "$color"
      return
    fi
    idx=$(_cmux_hash_index "$main_wt")
  else
    idx=$(( RANDOM % 16 ))
  fi
  print -r -- "${_CMUX_COLORS[idx+1]}"
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

# _cm_cd [path] <2|3|4|5|6>
#
# Implementation for `cm cd`. Open a new cmux workspace with a predefined
# split layout. Path defaults to $PWD; literal paths are tried first, then
# `zoxide query`. Workspace is named "<repo>:<branch>" (description = basename
# of target) if target is inside a git repo; otherwise named after the
# directory basename.
_cm_cd() {
  local target n
  case $# in
    1) target=$PWD; n=$1 ;;
    2) target=$1;   n=$2 ;;
    *) echo "usage: cm cd [path] <2|3|4|5|6>" >&2; return 2 ;;
  esac

  if [[ ! "$n" =~ ^[2-6]$ ]]; then
    echo "usage: cm cd [path] <2|3|4|5|6>" >&2
    return 2
  fi

  # Resolve target: try literal path first (with ~ expansion + realpath),
  # then fall back to `zoxide query` so `cm cd dotf 4` finds ~/.dotfiles.
  local expanded="${~target}"
  local resolved=${expanded:A}
  if [[ -d "$resolved" ]]; then
    target="$resolved"
  elif command -v zoxide >/dev/null 2>&1 && \
       resolved=$(zoxide query -- "$target" 2>/dev/null) && \
       [[ -d "$resolved" ]]; then
    target="$resolved"
  else
    echo "cm cd: not a directory: $target" >&2
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
  # Capture stdout (`OK workspace:N`) so we can color the new workspace.
  # Errors still surface via stderr.
  local out ws_ref=""
  out=$(_cmux_bin "${args[@]}")
  [[ "$out" =~ 'workspace:[0-9]+' ]] && ws_ref=$MATCH

  # Color the workspace before closing the caller so it's visible immediately.
  if [[ -n "$ws_ref" ]]; then
    local color
    color=$(_cmux_color_for_target "$target")
    _cmux_bin workspace-action --action set-color \
              --workspace "$ws_ref" --color "$color" >/dev/null 2>&1 || true
  fi

  # Close the caller workspace AFTER focus has moved to the new one.
  # Background + disown so this shell isn't killed mid-function.
  if [[ -n "$caller_ws" && "$caller_panes" == "1" ]]; then
    ( _cmux_bin close-workspace --workspace "$caller_ws" >/dev/null 2>&1 ) &
    disown 2>/dev/null
  fi
}

# _cm_wt
#
# Implementation for `cm wt`. Fzf-pick a git worktree and broadcast `cd <path>`
# to every terminal surface in the current cmux workspace. Local shell cd's
# first; broadcast follows. When not running inside a cmux workspace (no panes
# found), the local cd still happens and the broadcast is skipped with a notice.
_cm_wt() {
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
    echo "cm wt: failed to cd into $selected_worktree" >&2
    return 1
  fi

  local broadcaster
  broadcaster=$(command -v cmux-cd-all 2>/dev/null)
  [[ -z "$broadcaster" && -x "$HOME/.dotfiles/bin/cmux-cd-all" ]] && \
    broadcaster="$HOME/.dotfiles/bin/cmux-cd-all"

  if [[ -z "$broadcaster" ]]; then
    echo "cm wt: cmux-cd-all not found — local cd only" >&2
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
      echo "cm wt: not in a cmux workspace — local cd only" >&2
    fi
  fi

  echo "Switched to worktree: $selected_worktree"
  ls -a
}

# _cmux_color_key_for <path> — echo the canonical color-map key (main worktree
# path) for <path>, or just the realpath if <path> isn't in a git repo.
_cmux_color_key_for() {
  local target=$1 toplevel common_dir
  if toplevel=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null); then
    common_dir=$(git -C "$target" rev-parse --git-common-dir 2>/dev/null)
    [[ "$common_dir" != /* ]] && common_dir="$toplevel/$common_dir"
    print -r -- "${${common_dir:A}:h}"
  else
    print -r -- "${target:A}"
  fi
}

# Apply the persisted color map to every open cmux workspace in the current
# window. Matches each workspace's "<repo>:<branch>" name (repo = basename of
# the main worktree) against a map entry's key basename, then calls
# `workspace-action --action set-color`. Best-effort — silent if cmux isn't
# reachable or a workspace doesn't match any map entry. Prints a count of
# how many were applied (only when >0).
_cmux_apply_map_to_open_workspaces() {
  local ws_output
  ws_output=$(_cmux_bin list-workspaces 2>/dev/null) || return 0
  [[ -z "$ws_output" ]] && return 0
  local -A basename_to_color
  if _cmux_color_lock; then
    {
      _cmux_color_read_map
      local k
      for k in ${(k)_cmux_color_by_path}; do
        basename_to_color[${k:t}]=${_cmux_color_by_path[$k]}
      done
    } always {
      _cmux_color_unlock
    }
  fi
  (( ${#basename_to_color} == 0 )) && return 0
  local applied=0 line ws_ref ws_name ws_repo color
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ws_ref=$(print -r -- "$line" | awk '{for(i=1;i<=NF;i++) if($i~/^workspace:/){print $i; exit}}')
    [[ -z "$ws_ref" ]] && continue
    ws_name=$(print -r -- "$line" | awk -v ref="$ws_ref" '{
      for (i=1; i<=NF; i++) if ($i == ref) { print $(i+1); exit }
    }')
    [[ -z "$ws_name" ]] && continue
    ws_repo=${ws_name%%:*}
    color=${basename_to_color[$ws_repo]:-}
    if [[ -n "$color" ]]; then
      if _cmux_bin workspace-action --action set-color \
                   --workspace "$ws_ref" --color "$color" >/dev/null 2>&1; then
        applied=$((applied + 1))
      fi
    fi
  done <<< "$ws_output"
  (( applied > 0 )) && printf 'applied live to %d open workspace(s)\n' $applied
  return 0
}

# _cm_color show [path]   — print the resolved color and the key it's stored under
# _cm_color list          — list all assignments, oldest first
# _cm_color forget <path> — drop an assignment so the next `cm cd` re-rolls it
_cm_color() {
  local sub=${1:-show}
  (( $# > 0 )) && shift
  case "$sub" in
    show)
      local target=${1:-$PWD} expanded
      expanded="${~target}"
      target=${expanded:A}
      if [[ ! -d "$target" ]]; then
        echo "cm color: not a directory: ${1:-$PWD}" >&2
        return 2
      fi
      local key color
      key=$(_cmux_color_key_for "$target")
      color=$(_cmux_color_for_target "$target")
      printf 'target: %s\n' "$target"
      printf 'key:    %s\n' "$key"
      printf 'color:  %s\n' "$color"
      ;;
    list)
      _cmux_color_lock || { echo "cm color: could not acquire lock" >&2; return 1; }
      {
        _cmux_color_read_map
        local p
        local -a rows
        for p in ${(k)_cmux_color_by_path}; do
          rows+=("${_cmux_color_lastused_by_path[$p]}	${_cmux_color_by_path[$p]}	$p")
        done
        if (( ${#rows} == 0 )); then
          echo "(no assignments)"
        else
          printf '%-12s %-10s %s\n' "LAST_USED" "COLOR" "PATH"
          print -rl -- ${(on)rows} | awk -F'\t' '{printf "%-12s %-10s %s\n", $1, $2, $3}'
        fi
      } always {
        _cmux_color_unlock
      }
      ;;
    forget)
      if [[ -z "${1:-}" ]]; then
        echo "usage: cm color forget <path>" >&2
        return 2
      fi
      local target expanded key
      expanded="${~1}"
      target=${expanded:A}
      [[ -z "$target" ]] && target=$1
      _cmux_color_lock || { echo "cm color: could not acquire lock" >&2; return 1; }
      {
        _cmux_color_read_map
        key=$(_cmux_color_key_for "$target")
        if [[ -n "${_cmux_color_by_path[$key]:-}" ]]; then
          local old=${_cmux_color_by_path[$key]}
          unset "_cmux_color_by_path[$key]"
          unset "_cmux_color_lastused_by_path[$key]"
          _cmux_color_write_map
          echo "forgot: $key (was $old)"
        else
          echo "not found: $key"
        fi
      } always {
        _cmux_color_unlock
      }
      ;;
    dice)
      if [[ "${1:-}" == "all" ]]; then
        # Bulk re-roll every entry in the persisted map. Best-effort
        # uniqueness: each palette color is used once before any is reused;
        # each entry's new color is guaranteed != its current color (unless
        # impossible). Keys are shuffled so the pick order is fair across
        # repos. If we're inside a cmux workspace, re-apply the current
        # workspace's new color via set-color.
        _cmux_color_lock || { echo "cm color dice all: could not acquire lock" >&2; return 1; }
        local rolled=0
        {
          _cmux_color_read_map
          local -a keys
          keys=(${(k)_cmux_color_by_path})
          if (( ${#keys} == 0 )); then
            echo "(no assignments to roll)"
          else
            # Fisher-Yates shuffle of keys.
            local -a shuffled
            shuffled=("${keys[@]}")
            local i j tmp
            for (( i=${#shuffled}; i>=2; i-- )); do
              j=$(( RANDOM % i + 1 ))
              tmp=${shuffled[i]}; shuffled[i]=${shuffled[j]}; shuffled[j]=$tmp
            done
            local -A used_now
            local now=$(date +%s)
            local k old chosen c
            local -a candidates
            printf '%-10s %-10s %s\n' "OLD" "NEW" "PATH"
            for k in $shuffled; do
              old=${_cmux_color_by_path[$k]:-}
              candidates=()
              # Pass 1: unused-this-roll AND != old.
              for c in $_CMUX_COLORS; do
                [[ -z "${used_now[$c]:-}" && "$c" != "$old" ]] && candidates+=$c
              done
              # Pass 2: any != old (palette exhausted on this roll).
              if (( ${#candidates} == 0 )); then
                for c in $_CMUX_COLORS; do
                  [[ "$c" != "$old" ]] && candidates+=$c
                done
              fi
              (( ${#candidates} == 0 )) && candidates=($_CMUX_COLORS)
              chosen=${candidates[$(( RANDOM % ${#candidates} + 1 ))]}
              _cmux_color_by_path[$k]=$chosen
              _cmux_color_lastused_by_path[$k]=$now
              used_now[$chosen]=1
              rolled=$((rolled + 1))
              printf '%-10s %-10s %s\n' "$old" "$chosen" "$k"
            done
            _cmux_color_write_map
            printf '\nrolled %d assignment(s)\n' $rolled
          fi
        } always {
          _cmux_color_unlock
        }
        # Apply the new colors to every matching open workspace (not just
        # the current one — multiple workspaces of the same repo should
        # share the new color since they share one persisted entry).
        _cmux_apply_map_to_open_workspaces
        return 0
      fi
      # Re-roll the current cmux workspace's card color to a random palette
      # entry (different from the current one), persist it for this repo,
      # and apply it via `cmux workspace-action --action set-color`.
      local ws=${CMUX_WORKSPACE_ID:-}
      if [[ -z "$ws" ]]; then
        echo "cm color dice: not in a cmux workspace (CMUX_WORKSPACE_ID unset)" >&2
        return 1
      fi
      local key chosen current=""
      key=$(_cmux_color_key_for "$PWD")
      _cmux_color_lock || { echo "cm color dice: could not acquire lock" >&2; return 1; }
      {
        _cmux_color_read_map
        current=${_cmux_color_by_path[$key]:-}
        local -a candidates
        local c
        for c in $_CMUX_COLORS; do
          [[ "$c" != "$current" ]] && candidates+=$c
        done
        (( ${#candidates} == 0 )) && candidates=($_CMUX_COLORS)
        chosen=${candidates[$(( RANDOM % ${#candidates} + 1 ))]}
        _cmux_color_by_path[$key]=$chosen
        _cmux_color_lastused_by_path[$key]=$(date +%s)
        _cmux_color_write_map
      } always {
        _cmux_color_unlock
      }
      if [[ -n "$current" ]]; then
        printf 'rolled: %s -> %s\n' "$current" "$chosen"
      else
        printf 'rolled: %s\n' "$chosen"
      fi
      # Apply to every open workspace (including the current). Siblings of
      # the same repo all share one persisted entry, so they should all
      # update — not just the workspace we ran the command in.
      _cmux_apply_map_to_open_workspaces
      ;;
    -h|--help|help)
      cat >&2 <<'EOF'
Usage:
  cm color show [path]   Print resolved color for <path> (default: $PWD).
  cm color list          List all repo→color assignments, oldest first.
  cm color forget <path> Drop a repo's assignment so it gets re-rolled next time.
  cm color dice          Re-roll the current cmux workspace's card color.
  cm color dice all      Re-roll every entry in the persisted map.

Set CMUX_COLOR_DEBUG=1 to trace lock acquisition and picker decisions.
State file: ${XDG_CONFIG_HOME:-$HOME/.config}/cmux/colors.json
EOF
      ;;
    *)
      echo "cm color: unknown subcommand '$sub' (try 'cm color help')" >&2
      return 2
      ;;
  esac
}

# cm - cmux quick-commands (dispatcher)
#
# Usage:
#   cm cd [path] <2|3|4|5|6>   Open new workspace with N-pane layout.
#   cm wt                      Fzf-pick a worktree; broadcast cd to all panes.
#   cm color show [path]       Resolved color for path (default: $PWD).
#   cm color list              List all repo→color assignments, oldest first.
#   cm color forget <path>     Drop a repo's assignment.
#   cm color dice              Re-roll the current workspace's card color.
#   cm color dice all          Re-roll every entry in the persisted map.
#   cm help                    Show this help.
#
# Examples:
#   cm cd ~/.dotfiles 4   # 2x2 grid, workspace ".dotfiles:main"
#   cm cd dotf 3          # zoxide fuzzy match -> ~/.dotfiles
#   cm cd 2               # side-by-side in $PWD
#   cm wt                 # fzf-pick worktree, broadcast cd to all panes
#   cm color dice         # random new card color for this workspace
#   cm color dice all     # bulk re-roll every tracked repo
cm() {
  local cmd=${1:-help}
  (( $# > 0 )) && shift
  case "$cmd" in
    cd)             _cm_cd "$@" ;;
    wt)             _cm_wt "$@" ;;
    color)          _cm_color "$@" ;;
    help|-h|--help) _cm_help ;;
    *) echo "cm: unknown subcommand '$cmd' (try 'cm help')" >&2; return 2 ;;
  esac
}

_cm_help() {
  cat >&2 <<'EOF'
cm - cmux quick-commands

Usage:
  cm cd [path] <2|3|4|5|6>   Open new workspace with N-pane layout.
  cm wt                      Fzf-pick a worktree; broadcast cd to all panes.
  cm color show [path]       Resolved color for path (default: $PWD).
  cm color list              List all repo→color assignments, oldest first.
  cm color forget <path>     Drop a repo's assignment.
  cm color dice              Re-roll the current workspace's card color.
  cm color dice all          Re-roll every entry in the persisted map.
  cm help                    Show this help.

Examples:
  cm cd ~/.dotfiles 4
  cm cd dotf 3
  cm cd 2
  cm wt
  cm color show
  cm color dice
  cm color dice all
EOF
}
