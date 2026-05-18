#!/bin/sh
# Claude Code status line: model, progress bar with tokens, session/daily/weekly costs, window resets

JQ=/home/linuxbrew/.linuxbrew/bin/jq
input=$(cat)
PERIOD_FILE="$HOME/.claude/period-costs.json"

model_id=$(echo "$input" | $JQ -r '.model.id // empty')
model_name=$(echo "$input" | $JQ -r '.model.display_name // empty')
session_id=$(echo "$input" | $JQ -r '.session_id // empty')
used_pct=$(echo "$input" | $JQ -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | $JQ -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | $JQ -r '.context_window.total_output_tokens // 0')
ctx_size=$(echo "$input" | $JQ -r '.context_window.context_window_size // 0')
total_tokens=$((total_input + total_output))

cost=$(echo "$input" | $JQ -r '.cost.total_cost_usd // empty')

# Session cost (live, 2 decimal places)
session_cost=$(echo "${cost:-0}" | awk '{printf "%.2f", $1}')

today=$(date +%Y-%m-%d)
week_ago=$(date -d "7 days ago" +%Y-%m-%d)

# Periodic flush: upsert this session's live cost into period-costs.json every 30s
# so concurrent sessions see each other's accrued spend in the daily/weekly totals.
# Runs in the background so statusline render is not blocked.
if [ -n "$session_id" ] && [ -n "$cost" ]; then
    marker="$HOME/.claude/.flush-${session_id}"
    do_flush=0
    if [ ! -f "$marker" ]; then
        do_flush=1
    else
        last=$(stat -c %Y "$marker" 2>/dev/null || echo 0)
        now=$(date +%s)
        [ $((now - last)) -ge 30 ] && do_flush=1
    fi
    if [ "$do_flush" = "1" ]; then
        touch "$marker"
        (
            now_ts=$(date +%s)
            TMP="${PERIOD_FILE}.tmp.$$"
            [ -f "$PERIOD_FILE" ] || echo '[]' > "$PERIOD_FILE"
            (
                flock 9
                # Never decrease stored cost: --resume restarts the CLI's cost counter at 0,
                # so a naive overwrite would erase prior spend. Stop hook does the authoritative
                # transcript-based recompute; this flush just keeps daily/weekly totals fresh
                # between turns.
                $JQ --arg sid "$session_id" --arg date "$today" --argjson cost "$cost" --argjson ts "$now_ts" '
                    if any(.[]; .session_id == $sid) then
                        map(if .session_id == $sid
                            then . + {cost: ([.cost, $cost] | max), timestamp: $ts}
                            else . end)
                    else
                        . + [{session_id: $sid, date: $date, cost: $cost, timestamp: $ts}]
                    end
                ' "$PERIOD_FILE" > "$TMP" 2>/dev/null \
                    && mv "$TMP" "$PERIOD_FILE"
                rm -f "$TMP"
            ) 9>"${PERIOD_FILE}.lock"
        ) >/dev/null 2>&1 &
    fi
fi

# Daily/weekly: archive sum EXCLUDING this session (avoid double-count with live cost)
daily_archived=0
weekly_archived=0
if [ -f "$PERIOD_FILE" ]; then
    daily_archived=$($JQ -r --arg today "$today" --arg sid "$session_id" \
        '[.[] | select(.date == $today and .session_id != $sid)] | map(.cost) | add // 0' \
        "$PERIOD_FILE" 2>/dev/null || echo 0)
    weekly_archived=$($JQ -r --arg since "$week_ago" --arg sid "$session_id" \
        '[.[] | select(.date >= $since and .session_id != $sid)] | map(.cost) | add // 0' \
        "$PERIOD_FILE" 2>/dev/null || echo 0)
fi

daily_cost=$(echo "${daily_archived:-0} ${cost:-0}" | awk '{printf "%.2f", $1 + $2}')
weekly_cost=$(echo "${weekly_archived:-0} ${cost:-0}" | awk '{printf "%.2f", $1 + $2}')

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
now_ts=$(date +%s)

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
        window_str="${window_str} | ${col}$(fmt_countdown $secs_5h)${pct_5h}${rst}${arrow_5h}"
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
        window_str="${window_str} | ${col}$(fmt_countdown $secs_7d)${pct_7d}${rst}${arrow_7d}"
    fi
fi

cost_str=" | S: \$${session_cost} | D: \$${daily_cost} | W: \$${weekly_cost}${window_str} |"

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
    ctx_str="[${bar}] ${used_fmt}/${ctx_fmt}"
elif [ -n "$used_pct" ]; then
    ctx_str="ctx: $(printf "%.0f" "$used_pct")%"
else
    ctx_str=""
fi

effort=$($JQ -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)

model_str=""
if [ -n "$model_name" ]; then
    if [ -n "$effort" ]; then
        model_str="$model_name ($effort) | "
    else
        model_str="$model_name | "
    fi
fi

if [ -n "$ctx_str" ]; then
    printf "%s%s%s" "$model_str" "$ctx_str" "$cost_str"
else
    printf "%s%s" "$model_str" "${cost_str# | }"
fi
