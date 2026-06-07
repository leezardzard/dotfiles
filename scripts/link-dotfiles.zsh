#!/bin/zsh
#
# Wire every tracked dotfile into $HOME via idempotent, loop-safe symlinks.
#
#   ./scripts/link-dotfiles.zsh           # apply links (default)
#   ./scripts/link-dotfiles.zsh status    # report each target, change nothing
#
# CONVENTION OVER REGISTRY: the link set is DERIVED from the `home/` tree, which
# mirrors $HOME. There is no hand-maintained list — drop a file under `home/`
# and it is linked automatically. The linking primitives live in
# scripts/lib/link.zsh. REPO_ROOT is derived from this script's own location, so
# it works regardless of the current directory.
#
# Linking rules (see derive_manifest):
#   - A top-level entry under home/ (e.g. home/.p10k.zsh) links to $HOME/<name>.
#   - A LEAF_LINK_DIR (.config, .claude) is NOT whole-dir linked — each of its
#     children links individually, so ~/.config and ~/.claude stay REAL dirs
#     holding machine-local entries alongside the per-app links.
#   - Anything git would ignore is skipped, so the link set == the tracked set
#     (runtime junk written through a symlink — logs, caches, colors.json —
#     never gets linked back as its own target).

set -u

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h}"
source "$SCRIPT_DIR/lib/link.zsh"

# Dirs under home/ that must NEVER be whole-dir linked (~/.config, ~/.claude
# hold machine-local state); link their children individually instead.
typeset -a LEAF_LINK_DIRS
LEAF_LINK_DIRS=(.config .claude)

# is_ignored <absolute-path> — true if git would ignore the path. Ties the link
# set to the tracked set. Falls back to "not ignored" when git is unavailable.
is_ignored() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "$REPO_ROOT" check-ignore -q -- "$1"
}

# derive_manifest — populate MANIFEST ("<repo-relative-source>|<abs-target>")
# by walking home/. (D) globs include dotfiles; (N) yields nothing on no match.
typeset -a MANIFEST
derive_manifest() {
  MANIFEST=()
  local entry name child
  for entry in "$REPO_ROOT/home"/*(DN); do
    name="${entry:t}"
    is_ignored "$entry" && continue
    if (( ${LEAF_LINK_DIRS[(Ie)$name]} )); then
      for child in "$entry"/*(DN); do
        is_ignored "$child" && continue
        MANIFEST+=( "home/$name/${child:t}|$HOME/$name/${child:t}" )
      done
    else
      MANIFEST+=( "home/$name|$HOME/$name" )
    fi
  done
}

link_apply() {
  guard_config_symlink || return 1
  derive_manifest
  print "Linking dotfiles from $REPO_ROOT/home:"
  local pair
  for pair in "${MANIFEST[@]}"; do
    link "${pair%%|*}" "${pair#*|}"
  done
}

link_report() {
  derive_manifest
  print "Dotfile link status ($REPO_ROOT/home):"
  local pair
  for pair in "${MANIFEST[@]}"; do
    link_status "${pair%%|*}" "${pair#*|}"
  done
}

main() {
  case "${1:-apply}" in
    apply)        link_apply ;;
    status|check) link_report ;;
    *) print -u2 "usage: ${0:t} [apply|status]"; return 2 ;;
  esac
}

main "$@"
