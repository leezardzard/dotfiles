#!/usr/bin/env bash
# Claude Code status line — four-line "bullet" style, verbose labels.
# Foreground-only segments joined by a dim middot, so the translucent
# background shows through. Colors use ANSI 0-15 → inherit the terminal
# palette (Morandi here). Bright slots (8-15) for readable text on dark bg.
#
# Line 1 (location):  [worktree ·] dir … · [app … ·] branch … · <state words>
# Line 2 (model/ctx):  model … · style … · context ▰▰▱▱▱ NN% used [· exceeds 200k]
# Line 3 (session):    session · elapsed … · api … · cost … · rate … · lines … · resets …
# Line 4 (week/model): this week · Opus 4.8 $143 · … · total $228 · resets …
#
# Weekly per-model totals + reset windows come from `ccusage` (local usage logs),
# cached at ~/.claude/.statusline-weekly.json, refreshed in the background every 10m.
# "resets" on L3 = active 5h block end; on L4 = weekly bucket (period + 7d).
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
# remaining seconds → compact "2h30m" / "4d2h" / "12m"
fmt_left() {
  local s=$1; [ "$s" -lt 0 ] && s=0
  local m=$(( s / 60 ))
  if   [ "$m" -lt 60 ];   then printf '%dm' "$m"
  elif [ "$m" -lt 1440 ]; then printf '%dh%dm' $(( m / 60 )) $(( m % 60 ))
  else printf '%dd%dh' $(( m / 1440 )) $(( (m % 1440) / 60 )); fi
}
# ISO-8601 UTC → epoch (BSD date; silent fail → empty)
iso_epoch() { local t=$1; t=${t%Z}; t=${t%.*}; date -u -j -f "%Y-%m-%dT%H:%M:%S" "$t" +%s 2>/dev/null; }

# ============================ weekly usage cache ==========================
CACHE="$HOME/.claude/.statusline-weekly.json"
LOCK="$HOME/.claude/.statusline-weekly.lock"
if [ -z "$(find "$CACHE" -mmin -10 2>/dev/null)" ]; then
  if mkdir "$LOCK" 2>/dev/null; then
    (
      trap 'rmdir "$LOCK" 2>/dev/null' EXIT
      tmp="$CACHE.tmp.$$"
      wk=$(npx ccusage weekly --json --breakdown 2>/dev/null)
      bl=$(npx ccusage blocks --active --json 2>/dev/null)
      [ -z "$bl" ] && bl='{"blocks":[]}'
      if [ -n "$wk" ]; then
        jq -nc --argjson w "$wk" --argjson b "$bl" '
          ($w.weekly[-1]) as $wk |
          { models: [$wk.modelBreakdowns[] | {m:.modelName, c:.cost}],
            total: $wk.totalCost,
            week_start: $wk.period,
            block_end: ($b.blocks[0].endTime // null) }' \
          >"$tmp" 2>/dev/null && mv "$tmp" "$CACHE"
      fi
      rm -f "$tmp" 2>/dev/null
    ) >/dev/null 2>&1 &
  fi
fi
block_end=""; week_start=""
if [ -f "$CACHE" ]; then
  block_end=$(jq -r '.block_end // empty' "$CACHE" 2>/dev/null)
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
# session block reset (5h window) — replaces the wall clock
if [ -n "$block_end" ] && [ "$block_end" != "null" ]; then
  ee=$(iso_epoch "$block_end")
  if [ -n "$ee" ]; then
    rem=$(( ee - $(date +%s) ))
    at=$(date -r "$ee" +%H:%M 2>/dev/null)
    rfg=7; [ "$rem" -lt 1800 ] && rfg=9   # rose when <30m left
    kv 3 resets "$rfg" "$(fmt_left "$rem") (${at})"
  fi
fi

# ============================ LINE 4: this week per model ================
raw 4 "$(dim 'this week')"
if [ -f "$CACHE" ]; then
  while IFS=$'\t' read -r m c; do
    [ -z "$m" ] && continue
    raw 4 "$(col "$(model_color "$m")" "$(shorten_model "$m")") $(col 7 "$(fmt_cost "$c")")"
  done < <(jq -r '.models[:5][] | "\(.m)\t\(.c)"' "$CACHE" 2>/dev/null)
  wtotal=$(jq -r '.total // empty' "$CACHE" 2>/dev/null)
  [ -n "$wtotal" ] && raw 4 "${ESC}[38;5;8mtotal ${RESET}$(col 15 "$(fmt_cost "$wtotal")")"
else
  raw 4 "$(dim 'loading…')"
fi
# weekly bucket reset (period + 7 days)
if [ -n "$week_start" ] && [ "$week_start" != "null" ]; then
  ws=$(date -j -f "%Y-%m-%d %H:%M:%S" "$week_start 00:00:00" +%s 2>/dev/null)
  if [ -n "$ws" ]; then
    reset=$(( ws + 7 * 86400 ))
    rem=$(( reset - $(date +%s) ))
    on=$(date -r "$reset" "+%a %b %d" 2>/dev/null)
    kv 4 resets 7 "$(fmt_left "$rem") (${on})"
  fi
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
