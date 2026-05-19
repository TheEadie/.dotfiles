#!/bin/sh
# Claude Code status line: model, progress bar with tokens, session/daily/weekly costs, window resets

JQ=/home/linuxbrew/.linuxbrew/bin/jq
PROC_DIR="$HOME/.claude/processes"
mkdir -p "$PROC_DIR"

input=$(cat)

model_name=$(echo "$input" | $JQ -r '.model.display_name // empty')
used_pct=$(echo "$input" | $JQ -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | $JQ -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | $JQ -r '.context_window.total_output_tokens // 0')
ctx_size=$(echo "$input" | $JQ -r '.context_window.context_window_size // 0')
total_tokens=$((total_input + total_output))

raw_cost=$(echo "$input" | $JQ -r '.cost.total_cost_usd // empty')
raw_api_ms=$(echo "$input" | $JQ -r '.cost.total_api_duration_ms // empty')

today=$(date +%Y-%m-%d)
week_ago=$(date -d "7 days ago" +%Y-%m-%d)
now_s=$(date +%s)
now_ns=$(date +%s%N)

# Resolve the claude-code CLI PID. The statusline runs as a subprocess of CLI,
# so $PPID is normally CLI's PID. If a wrapper shell sits in between, walk up
# until we find a process whose comm looks like claude-code.
is_claude_proc() {
    pid=$1
    [ -r "/proc/$pid/comm" ] || return 1
    case "$(cat /proc/$pid/comm 2>/dev/null)" in
        *claude*|node) return 0 ;;
        *) return 1 ;;
    esac
}

cli_pid=$PPID
if ! is_claude_proc "$cli_pid"; then
    p=$cli_pid
    while [ "$p" != "1" ] && [ -r "/proc/$p/status" ]; do
        if is_claude_proc "$p"; then
            cli_pid=$p
            break
        fi
        p=$(awk '/^PPid:/ {print $2}' "/proc/$p/status" 2>/dev/null)
        [ -z "$p" ] && break
    done
fi

# Active-record lookup. The largest <started_at_ns> suffix is the most recent
# record for this PID. If raw counters dropped below the stored values, the PID
# was reused by a new CLI process — leave the old file as a permanent record
# and create a new one.
proc_file=""
if [ -n "$raw_cost" ] || [ -n "$raw_api_ms" ]; then
    match=$(ls -1 "$PROC_DIR/${cli_pid}-"*.json 2>/dev/null | sort | tail -n1)
    needs_new=1
    if [ -n "$match" ]; then
        stored_cost=$($JQ -r '.cost // 0' "$match" 2>/dev/null || echo 0)
        stored_api_ms=$($JQ -r '.api_ms // 0' "$match" 2>/dev/null || echo 0)
        regressed=$(awk -v rc="${raw_cost:-0}" -v sc="${stored_cost:-0}" \
                        -v ra="${raw_api_ms:-0}" -v sa="${stored_api_ms:-0}" \
                        'BEGIN { print (rc+0 < sc+0 || ra+0 < sa+0) ? 1 : 0 }')
        [ "$regressed" = "0" ] && needs_new=0
    fi

    if [ "$needs_new" = "1" ]; then
        proc_file="$PROC_DIR/${cli_pid}-${now_ns}.json"
        started_at=$now_s
        proc_date=$today
    else
        proc_file=$match
        started_at=$($JQ -r '.started_at // empty' "$proc_file" 2>/dev/null)
        proc_date=$($JQ -r '.date // empty' "$proc_file" 2>/dev/null)
        [ -z "$started_at" ] && started_at=$now_s
        [ -z "$proc_date" ] && proc_date=$today
    fi

    TMP="${proc_file}.tmp.$$"
    $JQ -n \
        --argjson pid "$cli_pid" \
        --argjson started_at "$started_at" \
        --arg date "$proc_date" \
        --argjson cost "${raw_cost:-0}" \
        --argjson api_ms "${raw_api_ms:-0}" \
        --argjson updated_at "$now_s" \
        '{pid: $pid, started_at: $started_at, date: $date, cost: $cost, api_ms: $api_ms, updated_at: $updated_at}' \
        > "$TMP" 2>/dev/null \
        && mv "$TMP" "$proc_file"
    rm -f "$TMP"
fi

# Best-effort prune of records older than 8 days (frees finished processes).
find "$PROC_DIR" -maxdepth 1 -type f -name '*.json' -mtime +8 -delete 2>/dev/null

# Sum cost and api_ms across all per-process files for today and the past week.
daily_cost=0
weekly_cost=0
daily_api_ms=0
weekly_api_ms=0
set -- "$PROC_DIR"/*.json
if [ -e "$1" ]; then
    sums=$($JQ -s -r --arg today "$today" --arg since "$week_ago" '
        {
          dc: ([.[] | select(.date == $today) | .cost // 0] | add // 0),
          wc: ([.[] | select(.date >= $since) | .cost // 0] | add // 0),
          dm: ([.[] | select(.date == $today) | .api_ms // 0] | add // 0),
          wm: ([.[] | select(.date >= $since) | .api_ms // 0] | add // 0)
        } | "\(.dc)\t\(.wc)\t\(.dm)\t\(.wm)"
    ' "$@" 2>/dev/null)
    if [ -n "$sums" ]; then
        IFS=$(printf '\t')
        set -- $sums
        daily_cost=${1:-0}
        weekly_cost=${2:-0}
        daily_api_ms=${3:-0}
        weekly_api_ms=${4:-0}
        unset IFS
    fi
fi

# Format ints for display.
session_cost=$(awk -v c="${raw_cost:-0}" 'BEGIN { printf "%.2f", c }')
daily_cost=$(awk -v c="$daily_cost" 'BEGIN { printf "%.2f", c }')
weekly_cost=$(awk -v c="$weekly_cost" 'BEGIN { printf "%.2f", c }')
daily_api_ms=$(awk -v m="$daily_api_ms" 'BEGIN { printf "%d", m }')
weekly_api_ms=$(awk -v m="$weekly_api_ms" 'BEGIN { printf "%d", m }')

# Rolling-window reset countdowns — from rate_limits fields in statusline JSON
fmt_countdown() {
    secs=$1
    if [ "$secs" -le 0 ]; then
        echo ""
        return
    fi
    days=$((secs / 86400))
    hrs=$(( (secs % 86400) / 3600 ))
    mins=$(( (secs % 3600) / 60 ))
    if [ "$days" -ge 1 ]; then
        printf "%dd%dh" "$days" "$hrs"
    elif [ "$hrs" -ge 1 ]; then
        printf "%dh%dm" "$hrs" "$mins"
    else
        printf "%dm" "$mins"
    fi
}

rl_resets_5h=$(echo "$input" | $JQ -r '.rate_limits.five_hour.resets_at // empty')
rl_resets_7d=$(echo "$input" | $JQ -r '.rate_limits.seven_day.resets_at // empty')
rl_pct_5h=$(echo "$input"    | $JQ -r '.rate_limits.five_hour.used_percentage // empty')
rl_pct_7d=$(echo "$input"    | $JQ -r '.rate_limits.seven_day.used_percentage // empty')

window_str=""
now_ts=$now_s

# Color a window section based on its used percentage: >=90 red, >=70 amber, else default.
window_color() {
    pct=$1
    [ -z "$pct" ] && return 0
    echo "$pct" | awk '{
        if ($1 >= 90)      printf "\033[31m"
        else if ($1 >= 70) printf "\033[33m"
    }'
}

# Pace arrow: projects final usage at reset (projected% = used% * window / elapsed)
# and renders ↑ red (will exhaust), → yellow (on pace), ↓ green (under-consuming).
pace_arrow() {
    pct=$1
    secs_remaining=$2
    window_duration=$3
    [ -z "$pct" ] && return 0
    [ "$secs_remaining" -le 0 ] && return 0
    elapsed=$(( window_duration - secs_remaining ))
    [ "$elapsed" -le 0 ] && return 0
    echo "$pct $window_duration $elapsed" | awk '{
        projected = $1 * $2 / $3
        if (projected > 110)      printf " \033[31m↑\033[0m"
        else if (projected >= 90) printf " \033[33m→\033[0m"
        else                      printf " \033[32m↓\033[0m"
    }'
}

if [ -n "$rl_resets_5h" ] && [ "$rl_resets_5h" != "null" ]; then
    secs_5h=$(( rl_resets_5h - now_ts ))
    if [ "$secs_5h" -gt 0 ]; then
        pct_5h=""
        [ -n "$rl_pct_5h" ] && pct_5h=" $(printf "%.0f" "$rl_pct_5h")%"
        arrow_5h=$(pace_arrow "$rl_pct_5h" "$secs_5h" 18000)
        col=$(window_color "$rl_pct_5h")
        rst=""
        [ -n "$col" ] && rst=$(printf '\033[0m')
        window_str="${window_str}  ${col}$(fmt_countdown $secs_5h)${pct_5h}${rst}${arrow_5h}"
    fi
fi

if [ -n "$rl_resets_7d" ] && [ "$rl_resets_7d" != "null" ]; then
    secs_7d=$(( rl_resets_7d - now_ts ))
    if [ "$secs_7d" -gt 0 ]; then
        pct_7d=""
        [ -n "$rl_pct_7d" ] && pct_7d=" $(printf "%.0f" "$rl_pct_7d")%"
        arrow_7d=$(pace_arrow "$rl_pct_7d" "$secs_7d" 604800)
        col=$(window_color "$rl_pct_7d")
        rst=""
        [ -n "$col" ] && rst=$(printf '\033[0m')
        window_str="${window_str}  ${col}$(fmt_countdown $secs_7d)${pct_7d}${rst}${arrow_7d}"
    fi
fi

# Format API compute time in ms to a human-readable string (space-prefixed).
fmt_ms() {
    ms=$1
    [ "${ms:-0}" -le 0 ] 2>/dev/null && return
    secs=$(( ms / 1000 ))
    hrs=$(( secs / 3600 ))
    mins=$(( (secs % 3600) / 60 ))
    s=$(( secs % 60 ))
    if [ "$hrs" -ge 1 ]; then
        printf " %dh%dm" "$hrs" "$mins"
    elif [ "$mins" -ge 1 ]; then
        printf " %dm%ds" "$mins" "$s"
    else
        printf " %ds" "$s"
    fi
}

session_time=$(fmt_ms "${raw_api_ms:-0}")
daily_time=$(fmt_ms "$daily_api_ms")
weekly_time=$(fmt_ms "$weekly_api_ms")

cost_str="✨ \$${session_cost}${session_time}  🌅 \$${daily_cost}${daily_time}  🗓️ \$${weekly_cost}${weekly_time}${window_str}"

fmt_tokens() {
    echo "$1" | awk '{
        if ($1 >= 1000000) printf "%.1fM", $1/1000000
        else if ($1 >= 1000) printf "%.0fk", $1/1000
        else printf "%d", $1
    }'
}

if [ -n "$used_pct" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
    used_fmt=$(fmt_tokens "$total_tokens")
    ctx_fmt=$(fmt_tokens "$ctx_size")
    bar=$(echo "$used_pct $total_tokens" | awk '{
        width = 10
        filled = int($1 / 100 * width + 0.5)
        if (filled > width) filled = width
        if ($1 >= 70)                       color = "\033[31m"
        else if ($1 >= 40 || $2 >= 60000)   color = "\033[33m"
        else                                color = "\033[90m"
        dim   = "\033[90m"
        reset = "\033[0m"
        bar = color
        for (i = 1; i <= filled; i++) bar = bar "━"
        bar = bar dim
        for (i = filled+1; i <= width; i++) bar = bar "─"
        bar = bar reset
        printf "%s", bar
    }')
    ctx_str="🧠 [${bar}] ${used_fmt}/${ctx_fmt}"
elif [ -n "$used_pct" ]; then
    ctx_str="🧠 $(printf "%.0f" "$used_pct")%"
else
    ctx_str=""
fi

effort=$($JQ -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

model_str=""
if [ -n "$model_name" ]; then
    if [ -n "$effort" ]; then
        model_str="🤖 $model_name ($effort)"
    else
        model_str="🤖 $model_name"
    fi
fi

# Filesystem indicator (Linux vs Windows) and git info — uses git.exe on WSL
# mounts so repo lookups don't pay the WSL→Win9P round-trip on every keystroke.
current_dir=$(echo "$input" | $JQ -r '.workspace.current_dir // .cwd // empty')

fs_str=""
GIT_CMD=git
git_dir="$current_dir"
case "$current_dir" in
    /mnt/c/*|/mnt/d/*|/mnt/s/*)
        fs_str="🪟"
        GIT_CMD=git.exe
        git_dir=$(wslpath -w "$current_dir" 2>/dev/null || echo "$current_dir")
        ;;
    "") ;;
    *)
        fs_str="🐧"
        ;;
esac

git_str=""
if [ -n "$current_dir" ] && GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        branch=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" describe --tags --exact-match 2>/dev/null \
              || GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" rev-parse --short HEAD 2>/dev/null \
              || echo detached)
    fi
    git_str=$(printf '\033[1;35m⎇  %s\033[0m' "$branch")

    porcelain=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" status --porcelain 2>/dev/null)
    if [ -n "$porcelain" ]; then
        untracked=$(echo "$porcelain" | grep -c '^??')
        modified=$(echo "$porcelain"  | grep -c '^ M')
        deleted=$(echo "$porcelain"   | grep -c '^D')
        staged=$(echo "$porcelain"    | grep -c '^[MARC]')
        indicators=""
        [ "$untracked" -gt 0 ] && indicators="${indicators}?$untracked "
        [ "$modified"  -gt 0 ] && indicators="${indicators}!$modified "
        [ "$staged"    -gt 0 ] && indicators="${indicators}✓$staged "
        [ "$deleted"   -gt 0 ] && indicators="${indicators}✗$deleted "
        if [ -n "$indicators" ]; then
            git_str="$git_str $(printf '\033[1;31m[%s]\033[0m' "${indicators% }")"
        fi
    fi

    upstream=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    if [ -n "$upstream" ]; then
        ahead=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD  -C "$git_dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
        behind=$(GIT_OPTIONAL_LOCKS=0 $GIT_CMD -C "$git_dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
        if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
            diverge=""
            [ "$ahead"  -gt 0 ] && diverge="${diverge}↑$ahead"
            [ "$behind" -gt 0 ] && diverge="${diverge}↓$behind"
            git_str="$git_str $(printf '\033[1;33m%s\033[0m' "$diverge")"
        fi
    fi
fi

top_line="${fs_str}${model_str}"
[ -n "$git_str" ] && top_line="$top_line  $git_str"

if [ -n "$ctx_str" ]; then
    printf "%s\n%s  %s" "$top_line" "$ctx_str" "$cost_str"
else
    printf "%s\n%s" "$top_line" "$cost_str"
fi
