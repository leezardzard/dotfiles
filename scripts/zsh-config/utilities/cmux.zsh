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

# cm-open <2|3|4|5|6> [path]
#
# Open a new cmux workspace with a predefined split layout.
# Path defaults to $PWD. All panes inherit the workspace cwd.
#
# Examples:
#   cm-open 4 ~/.dotfiles   # 2x2 grid in ~/.dotfiles
#   cm-open 3               # 2-left-stack + 1-right in $PWD
cm-open() {
  local n=${1:-}
  local target=${2:-$PWD}

  # Validate pane count
  if [[ ! "$n" =~ ^[2-6]$ ]]; then
    echo "usage: cm-open <2|3|4|5|6> [path]" >&2
    return 2
  fi

  # Resolve target: try literal path first (with ~ expansion + realpath),
  # then fall back to `zoxide query` so `cm-open 4 dotf` finds ~/.dotfiles.
  local expanded="${~target}"
  local resolved=${expanded:A}
  if [[ -d "$resolved" ]]; then
    target="$resolved"
  elif command -v zoxide >/dev/null 2>&1 && \
       resolved=$(zoxide query -- "$target" 2>/dev/null) && \
       [[ -d "$resolved" ]]; then
    target="$resolved"
  else
    echo "cm-open: not a directory: $target" >&2
    return 2
  fi

  local layout
  layout=$(_cmux_layout_json "$n")

  _cmux_bin new-workspace \
    --name "$n panes" \
    --cwd  "$target" \
    --layout "$layout"
}
