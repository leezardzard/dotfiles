###############################################################################
# Claude Code Profile Switcher using fzf
###############################################################################

# Resolve fzf path once so we work when PATH is minimal (e.g. Cursor terminal).
if [[ -n "${_CS_FZF:-}" && -x "$_CS_FZF" ]]; then
  : # already set
else
  _CS_FZF=$(command -v fzf 2>/dev/null)
  [[ -z "$_CS_FZF" && -x /opt/homebrew/bin/fzf ]] && _CS_FZF=/opt/homebrew/bin/fzf
  [[ -z "$_CS_FZF" && -x /usr/local/bin/fzf ]]    && _CS_FZF=/usr/local/bin/fzf
fi

_cs_fzf() {
  [[ -n "$_CS_FZF" && -x "$_CS_FZF" ]] || { echo "fzf not found" >&2; return 1 }
  "$_CS_FZF" "$@"
}

_CS_PROFILES_DIR="$HOME/.claude-profiles"

# --- Private helpers ---

_CS_DEFAULT_FILE="$_CS_PROFILES_DIR/.default"

# _cs_active_profile: Print the name of the currently active profile (or empty string).
# Detection: check ~/.claude.json symlink target, then fall back to CLAUDE_CONFIG_DIR.
_cs_active_profile() {
  # 1. Check symlink
  if [[ -L "$HOME/.claude.json" ]]; then
    local target
    target=$(readlink "$HOME/.claude.json" 2>/dev/null)
    if [[ "$target" == */.claude-profiles/*/. ]]; then
      # Extract profile name from path like /Users/x/.claude-profiles/personal/.claude.json
      local name="${target%/.claude.json}"
      name="${name##*/}"
      echo "$name"
      return 0
    fi
  fi
  # 2. Fallback: check CLAUDE_CONFIG_DIR
  if [[ -n "$CLAUDE_CONFIG_DIR" && "$CLAUDE_CONFIG_DIR" == */.claude-profiles/*/.claude ]]; then
    local name="${CLAUDE_CONFIG_DIR%/.claude}"
    name="${name##*/}"
    echo "$name"
    return 0
  fi
}

# _cs_profile_exists: Return 0 if profile directory exists.
_cs_profile_exists() {
  [[ -d "$_CS_PROFILES_DIR/$1" ]]
}

# _cs_apply_profile: Apply a profile silently without interactive prompts.
_cs_apply_profile() {
  local name="$1"
  if ! _cs_profile_exists "$name"; then
    echo "cs: default profile '$name' not found, skipping." >&2
    return 1
  fi
  export CLAUDE_CONFIG_DIR="$_CS_PROFILES_DIR/$name/.claude"
  ln -sf "$_CS_PROFILES_DIR/$name/.claude.json" "$HOME/.claude.json"
}

# _cs_autoload_default: Apply the default profile on shell startup if none is active.
_cs_autoload_default() {
  # Skip if a profile is already active in this shell
  [[ -n "$CLAUDE_CONFIG_DIR" ]] && return 0
  [[ -f "$_CS_DEFAULT_FILE" ]] || return 0

  local default_profile
  default_profile=$(< "$_CS_DEFAULT_FILE")
  [[ -z "$default_profile" ]] && return 0

  _cs_apply_profile "$default_profile"
}

# _cs_list_profiles: Print profile names, one per line, with (active) marker.
_cs_list_profiles() {
  [[ ! -d "$_CS_PROFILES_DIR" ]] && return 0
  local active
  active=$(_cs_active_profile)
  local name
  for name in "$_CS_PROFILES_DIR"/*(N:t); do
    if [[ "$name" == "$active" ]]; then
      echo "$name  (active)"
    else
      echo "$name"
    fi
  done
}

# --- Public functions ---

# claude_switch_go: Switch to a Claude profile. Interactive fzf pick if no name given.
claude_switch_go() {
  local name="$1"

  if [[ -z "$name" ]]; then
    # Interactive mode
    if [[ ! -d "$_CS_PROFILES_DIR" ]] || [[ -z "$(/bin/ls -A "$_CS_PROFILES_DIR" 2>/dev/null)" ]]; then
      echo "❌ No profiles found. Create one first with: cs add <name>"
      return 1
    fi

    local active
    active=$(_cs_active_profile)
    local header="ENTER to switch, ESC to cancel."
    [[ -n "$active" ]] && header="Current: $active. $header"

    local preview_cmd="echo '📁 Profile: {1}'; echo '---'; /usr/bin/stat -f 'Last modified: %Sm' $_CS_PROFILES_DIR/{1}/.claude.json 2>/dev/null || echo 'No .claude.json yet'; echo '---'; echo 'Config contents:'; ls $_CS_PROFILES_DIR/{1}/.claude/ 2>/dev/null || echo 'Empty config dir'"

    local selected
    selected=$(_cs_list_profiles | _cs_fzf \
      --prompt="Select Claude Profile> " \
      --header="$header" \
      --preview="$preview_cmd" \
      --preview-window=right:50%:wrap \
      | awk '{print $1}')

    [[ -z "$selected" ]] && return 0
    name="$selected"
  fi

  # Direct switch
  if ! _cs_profile_exists "$name"; then
    echo "❌ Profile '$name' not found at $_CS_PROFILES_DIR/$name"
    return 1
  fi

  # Safety: warn if ~/.claude.json is a regular file on first switch
  if [[ -f "$HOME/.claude.json" && ! -L "$HOME/.claude.json" ]]; then
    local profile_json="$_CS_PROFILES_DIR/$name/.claude.json"
    if [[ ! -s "$profile_json" ]]; then
      echo "⚠️  ~/.claude.json is not yet managed by cs."
      echo "   Your current config will be overwritten by a symlink."
      echo "   Consider seeding this profile first:"
      echo "     cp ~/.claude.json $_CS_PROFILES_DIR/$name/.claude.json"
      echo "     cp -r ~/.claude/* $_CS_PROFILES_DIR/$name/.claude/"
      printf "   Continue anyway? (y/n): "
      local confirm
      read -r confirm
      [[ "${confirm:l}" != "y" ]] && { echo "🔵 Cancelled."; return 0; }
    fi
  fi

  export CLAUDE_CONFIG_DIR="$_CS_PROFILES_DIR/$name/.claude"
  ln -sf "$_CS_PROFILES_DIR/$name/.claude.json" "$HOME/.claude.json"
  echo "✅ Switched to Claude profile: $name"
}

# claude_switch_list: Browse profiles in fzf with preview (view-only).
claude_switch_list() {
  if [[ ! -d "$_CS_PROFILES_DIR" ]] || [[ -z "$(/bin/ls -A "$_CS_PROFILES_DIR" 2>/dev/null)" ]]; then
    echo "No profiles found. Create one with: cs add <name>"
    return 0
  fi

  if [[ -n "$_CS_FZF" && -x "$_CS_FZF" ]]; then
    local preview_cmd="echo '📁 Profile: {1}'; echo '---'; /usr/bin/stat -f 'Last modified: %Sm' $_CS_PROFILES_DIR/{1}/.claude.json 2>/dev/null || echo 'No .claude.json yet'; echo '---'; echo 'Config contents:'; ls $_CS_PROFILES_DIR/{1}/.claude/ 2>/dev/null || echo 'Empty config dir'"

    _cs_list_profiles | _cs_fzf \
      --prompt="Claude Profiles> " \
      --header="View-only. ESC to exit. Use 'cs go' to switch." \
      --preview="$preview_cmd" \
      --preview-window=right:50%:wrap > /dev/null
  else
    _cs_list_profiles
  fi
}

# claude_switch_add: Create a new empty profile.
claude_switch_add() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "❌ Profile name is required."
    echo "Usage: cs add <name>"
    return 1
  fi

  if _cs_profile_exists "$name"; then
    echo "⚠️  Profile '$name' already exists at $_CS_PROFILES_DIR/$name"
    return 1
  fi

  mkdir -p "$_CS_PROFILES_DIR/$name/.claude"
  touch "$_CS_PROFILES_DIR/$name/.claude.json"
  echo "✅ Created profile: $name"
  echo "   Path: $_CS_PROFILES_DIR/$name"

  printf "Switch to it now? (y/n): "
  local confirm
  read -r confirm
  if [[ "${confirm:l}" == "y" ]]; then
    claude_switch_go "$name"
  fi
}

# claude_switch_mv: Clone or rename a profile.
# Usage: cs mv <source> <dest> [-c|--clone]
# Default: rename. With -c/--clone: copy instead.
claude_switch_mv() {
  local clone=0
  local src="" dest=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--clone) clone=1; shift ;;
      -*) echo "Usage: cs mv [-c|--clone] <source> <dest>" >&2; return 1 ;;
      *)
        if [[ -z "$src" ]]; then src="$1"
        elif [[ -z "$dest" ]]; then dest="$1"
        else echo "Usage: cs mv [-c|--clone] <source> <dest>" >&2; return 1
        fi
        shift ;;
    esac
  done

  if [[ -z "$src" || -z "$dest" ]]; then
    echo "❌ Source and destination names are required."
    echo "Usage: cs mv [-c|--clone] <source> <dest>"
    return 1
  fi

  if ! _cs_profile_exists "$src"; then
    echo "❌ Source profile '$src' not found."
    return 1
  fi

  if _cs_profile_exists "$dest"; then
    echo "❌ Destination profile '$dest' already exists."
    return 1
  fi

  local active
  active=$(_cs_active_profile)

  if (( clone )); then
    cp -r "$_CS_PROFILES_DIR/$src" "$_CS_PROFILES_DIR/$dest"
    echo "✅ Cloned profile '$src' → '$dest'"
  else
    mv "$_CS_PROFILES_DIR/$src" "$_CS_PROFILES_DIR/$dest"
    echo "✅ Renamed profile '$src' → '$dest'"
    # Update symlink/env if the renamed profile was active
    if [[ "$active" == "$src" ]]; then
      export CLAUDE_CONFIG_DIR="$_CS_PROFILES_DIR/$dest/.claude"
      ln -sf "$_CS_PROFILES_DIR/$dest/.claude.json" "$HOME/.claude.json"
      echo "   Active profile updated to '$dest'."
    fi
  fi
}

# claude_switch_default: Get or set the default profile loaded on new terminal windows.
# Usage: cs default [name|--clear]
claude_switch_default() {
  local name="$1"

  if [[ "$name" == "--clear" || "$name" == "-c" ]]; then
    rm -f "$_CS_DEFAULT_FILE"
    echo "✅ Default profile cleared."
    return 0
  fi

  if [[ -z "$name" ]]; then
    if [[ -f "$_CS_DEFAULT_FILE" ]]; then
      local current_default
      current_default=$(< "$_CS_DEFAULT_FILE")
      echo "Default profile: $current_default"
    else
      echo "No default profile set. Use: cs default <name>"
    fi
    return 0
  fi

  if ! _cs_profile_exists "$name"; then
    echo "❌ Profile '$name' not found at $_CS_PROFILES_DIR/$name"
    return 1
  fi

  echo "$name" > "$_CS_DEFAULT_FILE"
  echo "✅ Default profile set to: $name"
  echo "   Will auto-load on next terminal startup."
}

# claude_switch_help: Print usage.
claude_switch_help() {
  cat <<'EOF'
cs - Claude Code Profile Switcher (fzf)

Usage: cs [subcommand|profile-name] [args]

Subcommands:
  (none)              Interactive fzf picker to switch profiles.
  go [name]           Switch to a profile. Fzf picker if no name given.
  ls                  Browse profiles in fzf with preview (view-only).
  add <name>          Create a new empty profile.
  mv <src> <dest>     Rename a profile. Use -c/--clone to copy instead.
  default [name]      Get or set the default profile for new terminals.
  default --clear     Clear the default profile.
  help                Show this help.

Any unrecognized subcommand is treated as a profile name:
  cs work         → same as cs go work

Directory layout (~/.claude-profiles/):
  <profile>/
    .claude/         Config directory (CLAUDE_CONFIG_DIR)
    .claude.json     Auth/credentials (symlinked to ~/.claude.json)

Setup:
  cs add personal
  cp -r ~/.claude/* ~/.claude-profiles/personal/.claude/
  cp ~/.claude.json ~/.claude-profiles/personal/.claude.json
  cs add work
  cs personal       # switch to personal profile
EOF
}

# --- cs: single entry point ---
cs() {
  if [[ -z "$1" ]]; then
    claude_switch_go
    return $?
  fi
  local cmd="$1"; shift
  case "$cmd" in
    go)      claude_switch_go "$@" ;;
    ls)      claude_switch_list "$@" ;;
    add)     claude_switch_add "$@" ;;
    mv)      claude_switch_mv "$@" ;;
    default) claude_switch_default "$@" ;;
    help|-h|--help) claude_switch_help ;;
    *)       claude_switch_go "$cmd" ;;
  esac
}

# Auto-apply default profile when this script is sourced (new terminal window).
_cs_autoload_default
