#!/bin/zsh
#
# Idempotent, loop-safe symlink primitives for wiring tracked dotfiles into
# $HOME. Pure functions — the caller sets $REPO_ROOT (the repo root) before
# invoking them.
#
# Every "Too many levels of symbolic links" (ELOOP) failure this repo used to
# hit came from ONE thing: mixing symlink granularities — a per-app link
# (~/.config/ghostty -> repo/home/.config/ghostty) layered on top of a whole-dir
# link (~/.config -> repo/home/.config). When ~/.config already *is* the repo dir,
# naively `mv`-ing a leaf aside and `ln -s`-ing it back points a path at
# itself. Two rules kill the whole class:
#   1. Never link the whole ~/.config         -> guard_config_symlink
#   2. Never mv+ln a target that already       -> the `-ef` guard in link()
#      resolves to its source

# guard_config_symlink
# Abort if ~/.config is a symlink into a dotfiles checkout. ~/.config must stay
# a REAL directory: this repo links per-app leaves (~/.config/nvim,
# ~/.config/ghostty, ...) which must coexist with machine-local ~/.config
# entries that should never be tracked. A whole-dir link collides with those
# per-app links (ELOOP) and drags local config into the repo.
guard_config_symlink() {
  [[ -L "$HOME/.config" ]] || return 0

  local target="$HOME/.config"
  target="${target:A}"            # fully resolved absolute path

  # Two ways the link aims into a dotfiles repo and must be undone:
  #   1. the resolved target lives inside THIS repo (home/.config and friends), or
  #   2. some ancestor of the resolved target is a git checkout (a foreign repo).
  # .git is a directory in a normal clone, a file in a linked worktree — `-e`
  # catches both. Walk ancestors so the depth of home/ doesn't matter.
  local in_repo=0 d="${target:h}"
  [[ "$target" == "${REPO_ROOT:-/dev/null}"/* ]] && in_repo=1
  while (( ! in_repo )) && [[ -n "$d" && "$d" != "/" && "$d" != "$HOME" ]]; do
    [[ -e "$d/.git" ]] && { in_repo=1; break; }
    d="${d:h}"
  done

  if (( in_repo )); then
    print -u2 "error: ~/.config is a whole-dir symlink into a dotfiles repo:"
    print -u2 "         ~/.config -> $target"
    print -u2 ""
    print -u2 "  This repo links per-app leaves (~/.config/nvim, ~/.config/ghostty,"
    print -u2 "  ...), which requires ~/.config to be a REAL directory. A whole-dir"
    print -u2 "  link causes ELOOP collisions with the per-app links and forces"
    print -u2 "  machine-local ~/.config entries to live in the repo."
    print -u2 ""
    print -u2 "  Migrate (tracked configs stay safe inside the repo):"
    print -u2 "    rm ~/.config && mkdir -p ~/.config"
    print -u2 "    ./scripts/link-dotfiles.zsh apply"
    return 1
  fi
}

# link <repo-relative-source> <absolute-target>
# Symlink target -> source. Idempotent: no-op when the target already resolves
# to the source; otherwise backs up any existing real file/dir or stale link
# before creating the symlink.
link() {
  local src="$REPO_ROOT/$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    print "  skip     $dst (source missing: $src)"
    return 0
  fi

  # -ef: same inode. True for an already-correct link AND for the case where a
  # parent of $dst is itself a link into the repo — both mean "nothing to do",
  # and crucially prevents mv+ln-ing a path onto itself (the ELOOP bug).
  if [[ "$dst" -ef "$src" ]]; then
    print "  ok       $dst"
    return 0
  fi

  mkdir -p "${dst:h}"
  if [[ -e "$dst" || -L "$dst" ]]; then
    local backup="$dst.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$backup"
    print "  backup   $dst -> ${backup:t}"
  fi
  ln -s "$src" "$dst"
  print "  linked   $dst -> $src"
}

# link_status <repo-relative-source> <absolute-target>
# Report the state of one target without changing anything.
link_status() {
  local src="$REPO_ROOT/$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    print "  missing-src  $dst (no $src)"
  elif [[ "$dst" -ef "$src" ]]; then
    print "  linked       $dst"
  elif [[ -e "$dst" || -L "$dst" ]]; then
    print "  drifted      $dst (real file or points elsewhere)"
  else
    print "  absent       $dst"
  fi
}
