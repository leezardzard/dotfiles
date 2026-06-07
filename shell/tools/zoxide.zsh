###############################################################################
# Setup zoxide and alias
###############################################################################
eval "$(zoxide init zsh)"

# Shadow `cd` with zoxide's frecency jump (`z`) ONLY in interactive shells.
#
# In non-interactive shells — notably Claude Code's shell-snapshot replay — the
# captured snapshot restores aliases/functions but NOT the chpwd_functions
# array, so `__zoxide_hook` is missing. Routing `cd` through `z` there has two
# bad effects: every `cd` trips a spurious `zoxide doctor` warning (the doctor
# only checks that the hook is present), and `cd <fuzzy-or-missing-path>` fails
# with "no match found" / exit 1 instead of a normal cd error. Falling back to
# the real builtin `cd` keeps agent/script shells well-behaved.
#
# `unalias` first: zsh expands aliases at parse time, so defining a `cd`
# function while a `cd` alias exists (e.g. from re-sourcing this file) is a
# parse error. Clearing it makes this file safe to source repeatedly.
unalias cd 2>/dev/null
cd() {
  if [[ -o interactive ]]; then
    z "$@"
  else
    builtin cd "$@"
  fi
}
