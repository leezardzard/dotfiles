#!/usr/bin/env bash
# Claude Code status line — four-line "bullet" style, verbose labels.
# Foreground-only segments joined by a dim middot, so the translucent
# background shows through. Colors use ANSI 0-15 → inherit the terminal
# palette (Morandi here). Bright slots (8-15) for readable text on dark bg.
#
# Line 1 (location):  [worktree ·] dir … · [app … ·] branch … · <state words>
# Line 2 (model/ctx):  model … · style … · context ▰▰▱▱▱ NN% used [· exceeds 200k]
# Line 3 (session):    session · elapsed … · api … · cost … · lines … · time ▰▰▱▱▱ 2h/5h (15:00) · spend ▰▱▱▱▱ $9/$50
# Line 4 (week/model): this week · Opus 4.8 $143 · … · time ▰▰▰▱▱ 4d/7d (Mon Jul 27) · spend ▰▰▰▱▱ $213/$300
#
# Weekly per-model totals + block/window data come from `ccusage` (local usage logs),
# cached at ~/.claude/.statusline-weekly.json, refreshed in the background every 10m.
# The "time" bars show elapsed/total through the reset window (L3 = active 5h block,
# L4 = weekly period + 7d); the "spend" bars show cost against a budget, overridable via:
#   STATUSLINE_BLOCK_BUDGET (default 50)   STATUSLINE_WEEK_BUDGET (default 300)   — USD.
# A stale lock (>10m old) is auto-reclaimed, so a died refresh can't freeze the cache.
# Debug: `STATUSLINE_DEBUG=1 claude` appends raw payloads to /tmp/claude-statusline.jsonl
set -u

input=$(cat)
[ -n "${STATUSLINE_DEBUG:-}" ] && printf '%s\n' "$input" >> /tmp/claude-statusline.jsonl

# --- extract session fields ---
cwd=$(jq -r '.workspace.current_dir // .cwd // ""'       <<<"$input")
model=$(jq -r '.model.display_name // ""'                <<<"$input")
used=$(jq -r '.context_window.used_percentage // empty'  <<<"$input")
cost=$(jq -r '.cost.total_cost_usd // empty'             <<<"$input")
added=$(jq -r '.cost.total_lines_added // empty'         <<<"$input")
removed=$(jq -r '.cost.total_lines_removed // empty'     <<<"$input")
dur_ms=$(jq -r '.cost.total_duration_ms // empty'        <<<"$input")
api_ms=$(jq -r '.cost.total_api_duration_ms // empty'    <<<"$input")
out_style=$(jq -r '.output_style.name // empty'          <<<"$input")
exceeds=$(jq -r '.exceeds_200k_tokens // empty'          <<<"$input")

# --- spend-bar budgets (USD; override via env) ---
BLOCK_BUDGET=${STATUSLINE_BLOCK_BUDGET:-50}
WEEK_BUDGET=${STATUSLINE_WEEK_BUDGET:-300}

# --- ANSI plumbing ---
ESC=$'\033'
RESET="${ESC}[0m"
DIV=" ${ESC}[38;5;8m·${RESET} "
dim()  { printf '%s' "${ESC}[38;5;8m$1${RESET}"; }
col()  { printf '%s' "${ESC}[38;5;$1m$2${RESET}"; }

p1=() p2=() p3=() p4=()
raw() { case "$1" in 1) p1+=("$2");; 2) p2+=("$2");; 3) p3+=("$2");; 4) p4+=("$2");; esac; }
add() { raw "$1" "$(col "$2" "$3")"; }
kv()  { raw "$1" "${ESC}[38;5;8m$2 ${RESET}$(col "$3" "$4")"; }
join_pieces() {
  local out="" i=0
  for seg in "$@"; do [ "$i" -gt 0 ] && out+="$DIV"; out+="$seg"; i=$((i+1)); done
  printf '%s' "$out"
}
fmt_dur() {
  local s=$(( $1 / 1000 ))
  if   [ "$s" -lt 60 ];   then printf '%ds' "$s"
  elif [ "$s" -lt 3600 ]; then printf '%dm' $(( s / 60 ))
  else printf '%dh%dm' $(( s / 3600 )) $(( (s % 3600) / 60 )); fi
}
# ISO-8601 UTC → epoch (BSD date; silent fail → empty)
iso_epoch() { local t=$1; t=${t%Z}; t=${t%.*}; date -u -j -f "%Y-%m-%dT%H:%M:%S" "$t" +%s 2>/dev/null; }
# portable timeout: `_timeout <secs> <outfile> cmd…` — runs cmd with stdout to outfile,
# killing it if it overruns. BSD has no timeout(1); bash 3.2 makes `set -m` unreliable in
# $(). Writing to a FILE (not a command-substitution pipe) means a lingering child can
# never block the caller — we read the file after wait/kill no matter what the subtree does.
_timeout() {
  local t=$1 of=$2; shift 2
  "$@" >"$of" 2>/dev/null & local p=$!
  ( sleep "$t"; kill -9 "$p" 2>/dev/null ) >/dev/null 2>&1 & local k=$!
  wait "$p" 2>/dev/null
  kill "$k" 2>/dev/null
}
# integer percent (rounded, may exceed 100) → 5-cell bar, green/amber/rose by fill
usage_bar() {
  local pct=$1; [ "$pct" -lt 0 ] && pct=0
  local f=$(( (pct + 10) / 20 )); [ "$f" -gt 5 ] && f=5; [ "$f" -lt 0 ] && f=0
  local b="" i; for ((i=0; i<5; i++)); do [ "$i" -lt "$f" ] && b+="▰" || b+="▱"; done
  local fg=10; [ "$pct" -ge 50 ] && fg=11; [ "$pct" -ge 80 ] && fg=9
  printf '%s' "${ESC}[38;5;${fg}m${b}${RESET}"
}
pct_of() { awk -v n="$1" -v d="$2" 'BEGIN{ if(d>0) printf "%d", (n/d*100)+0.5; else print 0 }'; }
# seconds → compact window spans: "45m" / "2h" / "2h30m" (hours) ; "5h" / "3d" / "3d5h" (days)
fmt_hm() { local s=$1; [ "$s" -lt 0 ] && s=0; local m=$(( s/60 ));
  if [ "$m" -lt 60 ]; then printf '%dm' "$m"; else local h=$((m/60)) r=$((m%60));
  [ "$r" -eq 0 ] && printf '%dh' "$h" || printf '%dh%dm' "$h" "$r"; fi; }
fmt_dh() { local s=$1; [ "$s" -lt 0 ] && s=0; local h=$(( s/3600 ));
  if [ "$h" -lt 24 ]; then printf '%dh' "$h"; else local d=$((h/24)) r=$((h%24));
  [ "$r" -eq 0 ] && printf '%dd' "$d" || printf '%dd%dh' "$d" "$r"; fi; }

# ============================ weekly usage cache ==========================
CACHE="$HOME/.claude/.statusline-weekly.json"
LOCK="$HOME/.claude/.statusline-weekly.lock"
if [ -z "$(find "$CACHE" -mmin -10 2>/dev/null)" ]; then
  # Reclaim a stale lock: a refresh that died (SIGKILL / reboot / hung ccusage) can't
  # run its EXIT trap, so the lock dir lingers and freezes the cache forever. Any lock
  # older than the refresh window means the owner is gone — drop it before acquiring.
  [ -d "$LOCK" ] && [ -z "$(find "$LOCK" -mmin -10 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null
  if mkdir "$LOCK" 2>/dev/null; then
    (
      trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
      tmp="$CACHE.tmp.$$"
      _timeout 30 "$tmp.wk" npx ccusage weekly --json --breakdown; wk=$(cat "$tmp.wk" 2>/dev/null)
      _timeout 30 "$tmp.bl" npx ccusage blocks --active --json;    bl=$(cat "$tmp.bl" 2>/dev/null)
      [ -z "$bl" ] && bl='{"blocks":[]}'
      if [ -n "$wk" ]; then
        jq -nc --argjson w "$wk" --argjson b "$bl" '
          ($w.weekly[-1]) as $wk |
          { models: [$wk.modelBreakdowns[] | {m:.modelName, c:.cost}],
            total: $wk.totalCost,
            week_start:  $wk.period,
            block_start: ($b.blocks[0].startTime // null),
            block_end:   ($b.blocks[0].endTime   // null),
            block_cost:  ($b.blocks[0].costUSD   // null) }' \
          >"$tmp" 2>/dev/null && mv "$tmp" "$CACHE"
      fi
      rm -f "$tmp" "$tmp.wk" "$tmp.bl" 2>/dev/null
    ) >/dev/null 2>&1 &
  fi
fi
block_start=""; block_end=""; block_cost=""; week_start=""
if [ -f "$CACHE" ]; then
  block_start=$(jq -r '.block_start // empty' "$CACHE" 2>/dev/null)
  block_end=$(jq -r '.block_end // empty' "$CACHE" 2>/dev/null)
  block_cost=$(jq -r '.block_cost // empty' "$CACHE" 2>/dev/null)
  week_start=$(jq -r '.week_start // empty' "$CACHE" 2>/dev/null)
fi
shorten_model() {
  local n=${1#claude-}
  n=$(printf '%s' "$n" | sed -E 's/-[0-9]{8}$//')
  local fam=${n%%-*} ver=${n#*-}; ver=${ver//-/.}
  fam="$(printf '%s' "${fam:0:1}" | tr '[:lower:]' '[:upper:]')${fam:1}"
  printf '%s %s' "$fam" "$ver"
}
model_color() { case "$1" in *opus*) printf 13;; *sonnet*) printf 12;; *haiku*) printf 14;; *) printf 7;; esac; }
fmt_cost() { awk -v c="$1" 'BEGIN{ if(c>=10) printf "$%.0f", c; else printf "$%.1f", c }'; }

# ============================ LINE 1: location ============================
in_worktree=0
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  case "$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)" in */worktrees/*) in_worktree=1;; esac
fi
[ "$in_worktree" -eq 1 ] && add 1 13 "worktree"

short_cwd=${cwd/#$HOME/\~}
IFS='/' read -ra _comps <<<"$short_cwd"
_n=${#_comps[@]}
[ "$_n" -gt 4 ] && short_cwd="${_comps[0]}/…/${_comps[_n-2]}/${_comps[_n-1]}"
kv 1 dir 12 "$short_cwd"

case "$cwd" in
  *apps/touchpoint-app*)    kv 1 app 14 "touchpoint-app" ;;
  *apps/touchpoint-server*) kv 1 app 14 "touchpoint-server" ;;
esac

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  staged=0 modified=0 untracked=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    x=${line:0:1}; y=${line:1:1}
    if [ "$x$y" = '??' ]; then untracked=$((untracked+1))
    else [ "$x" != ' ' ] && staged=$((staged+1)); [ "$y" != ' ' ] && modified=$((modified+1)); fi
  done < <(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
  ahead=0 behind=0
  if ab=$(git -C "$cwd" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null); then
    behind=${ab%%	*}; ahead=${ab##*	}
  fi
  words=""
  sp() { [ -n "$1" ] && { [ -n "$words" ] && words+=", "; words+="$1"; }; }
  [ "$staged"      -gt 0 ] && sp "${staged} staged"
  [ "$modified"    -gt 0 ] && sp "${modified} modified"
  [ "$untracked"   -gt 0 ] && sp "${untracked} untracked"
  [ "${ahead:-0}"  -gt 0 ] && sp "${ahead} ahead"
  [ "${behind:-0}" -gt 0 ] && sp "${behind} behind"
  if [ -z "$words" ]; then git_fg=10; words="clean"; else git_fg=11; fi
  raw 1 "${ESC}[38;5;8mbranch ${RESET}$(col "$git_fg" "$branch") $(dim "($words)")"
fi

# ============================ LINE 2: model / context ====================
[ -n "$model" ] && kv 2 model 13 "$model"
if [ -n "$out_style" ] && [ "$out_style" != "default" ] && [ "$out_style" != "null" ]; then
  kv 2 style 6 "$out_style"
fi
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  filled=$(( (used_int + 10) / 20 ))
  [ "$filled" -gt 5 ] && filled=5; [ "$filled" -lt 0 ] && filled=0
  bar=""; for ((i=0; i<5; i++)); do [ "$i" -lt "$filled" ] && bar+="▰" || bar+="▱"; done
  if   [ "$used_int" -lt 50 ]; then ctx_fg=10
  elif [ "$used_int" -lt 80 ]; then ctx_fg=11
  else                              ctx_fg=9; fi
  raw 2 "${ESC}[38;5;8mcontext ${RESET}${ESC}[38;5;${ctx_fg}m${bar} ${used_int}%${RESET} $(dim used)"
fi
[ "$exceeds" = "true" ] && add 2 9 "exceeds 200k tokens"

# ============================ LINE 3: this session =======================
raw 3 "$(dim session)"
[ -n "${dur_ms:-}" ] && [ "${dur_ms:-0}" -gt 0 ] 2>/dev/null && kv 3 elapsed 7 "$(fmt_dur "$dur_ms")"
[ -n "${api_ms:-}" ] && [ "${api_ms:-0}" -gt 0 ] 2>/dev/null && kv 3 api     8 "$(fmt_dur "$api_ms")"
if [ -n "$cost" ]; then
  kv 3 cost 7 "$(printf '$%.2f' "$cost")"
  if [ -n "${dur_ms:-}" ] && [ "${dur_ms:-0}" -gt 60000 ] 2>/dev/null; then
    rate=$(awk -v c="$cost" -v ms="$dur_ms" 'BEGIN{ h=ms/3600000.0; if(h>0) printf "%.2f", c/h }')
    [ -n "$rate" ] && kv 3 rate 8 "\$${rate}/h"
  fi
fi
lines_val=""
[ -n "${added:-}" ]   && [ "${added:-0}"   != "0" ] && lines_val+="$(col 10 "+${added}")"
[ -n "${removed:-}" ] && [ "${removed:-0}" != "0" ] && { [ -n "$lines_val" ] && lines_val+=" "; lines_val+="$(col 9 "-${removed}")"; }
[ -n "$lines_val" ] && raw 3 "${ESC}[38;5;8mlines ${RESET}${lines_val}"
# session 5h block: time-through-window bar (elapsed/total + reset clock) + spend bar
if [ -n "$block_start" ] && [ "$block_start" != "null" ] \
   && [ -n "$block_end" ] && [ "$block_end" != "null" ]; then
  bs=$(iso_epoch "$block_start"); be=$(iso_epoch "$block_end")
  if [ -n "$bs" ] && [ -n "$be" ] && [ "$be" -gt "$bs" ]; then
    total=$(( be - bs )); el=$(( $(date +%s) - bs ))
    [ "$el" -lt 0 ] && el=0; [ "$el" -gt "$total" ] && el="$total"
    at=$(date -r "$be" +%H:%M 2>/dev/null)
    raw 3 "${ESC}[38;5;8mtime ${RESET}$(usage_bar "$(( el * 100 / total ))") $(col 7 "$(fmt_hm "$el")/$(fmt_hm "$total")") $(dim "(${at})")"
  fi
fi
if [ -n "$block_cost" ] && [ "$block_cost" != "null" ]; then
  raw 3 "${ESC}[38;5;8mspend ${RESET}$(usage_bar "$(pct_of "$block_cost" "$BLOCK_BUDGET")") $(col 7 "$(fmt_cost "$block_cost")/$(fmt_cost "$BLOCK_BUDGET")")"
fi

# ============================ LINE 4: this week per model ================
raw 4 "$(dim 'this week')"
if [ -f "$CACHE" ]; then
  while IFS=$'\t' read -r m c; do
    [ -z "$m" ] && continue
    raw 4 "$(col "$(model_color "$m")" "$(shorten_model "$m")") $(col 7 "$(fmt_cost "$c")")"
  done < <(jq -r '.models[:5][] | "\(.m)\t\(.c)"' "$CACHE" 2>/dev/null)
else
  raw 4 "$(dim 'loading…')"
fi
# weekly 7-day window: time-through-window bar (elapsed/total + reset date)
if [ -n "$week_start" ] && [ "$week_start" != "null" ]; then
  ws=$(date -j -f "%Y-%m-%d %H:%M:%S" "$week_start 00:00:00" +%s 2>/dev/null)
  if [ -n "$ws" ]; then
    total=$(( 7 * 86400 )); reset=$(( ws + total )); el=$(( $(date +%s) - ws ))
    [ "$el" -lt 0 ] && el=0; [ "$el" -gt "$total" ] && el="$total"
    on=$(date -r "$reset" "+%a %b %d" 2>/dev/null)
    raw 4 "${ESC}[38;5;8mtime ${RESET}$(usage_bar "$(( el * 100 / total ))") $(col 7 "$(fmt_dh "$el")/$(fmt_dh "$total")") $(dim "(${on})")"
  fi
fi
# weekly spend bar (total vs budget) — folds in the old standalone "total" segment
if [ -f "$CACHE" ]; then
  wtotal=$(jq -r '.total // empty' "$CACHE" 2>/dev/null)
  [ -n "$wtotal" ] && raw 4 "${ESC}[38;5;8mspend ${RESET}$(usage_bar "$(pct_of "$wtotal" "$WEEK_BUDGET")") $(col 7 "$(fmt_cost "$wtotal")/$(fmt_cost "$WEEK_BUDGET")")"
fi

# ============================ emit (skip empty lines) =====================
out=""
emit() { [ -n "$1" ] && { [ -n "$out" ] && out+=$'\n'; out+="$1"; }; }
l1=""; [ "${#p1[@]}" -gt 0 ] && l1=$(join_pieces "${p1[@]}")
l2=""; [ "${#p2[@]}" -gt 0 ] && l2=$(join_pieces "${p2[@]}")
l3=""; [ "${#p3[@]}" -gt 0 ] && l3=$(join_pieces "${p3[@]}")
l4=""; [ "${#p4[@]}" -gt 0 ] && l4=$(join_pieces "${p4[@]}")
emit "$l1"; emit "$l2"; emit "$l3"; emit "$l4"
printf '%s' "$out"
