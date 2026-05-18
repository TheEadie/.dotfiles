#!/bin/sh
# Archive session cost to monthly cost log when session ends.
# Calculates cost from the transcript so sub-agent sessions are also tracked.

JQ=/home/linuxbrew/.linuxbrew/bin/jq
PERIOD_FILE="$HOME/.claude/period-costs.json"

input=$(cat 2>/dev/null || true)

session_id=$(echo "$input" | $JQ -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && exit 0

transcript=$(echo "$input" | $JQ -r '.transcript_path // empty' 2>/dev/null)
[ -z "$transcript" ] || [ ! -f "$transcript" ] && exit 0

# Extract per-model token totals from transcript.
# Deduplicate by message ID (same message appears once per content block).
model_data=$(cat "$transcript" | $JQ -r '
    [.[] | select(.type == "assistant" and .message.usage != null)]
    | unique_by(.message.id)
    | group_by(.message.model)[]
    | [
        (.[0].message.model),
        (map(.message.usage.input_tokens // 0) | add | tostring),
        (map(.message.usage.output_tokens // 0) | add | tostring),
        (map(.message.usage.cache_creation_input_tokens // 0) | add | tostring),
        (map(.message.usage.cache_read_input_tokens // 0) | add | tostring)
      ]
    | join("\t")
' 2>/dev/null)

[ -z "$model_data" ] && exit 0

total_cost=$(echo "$model_data" | awk '
BEGIN { FS="\t"; cost=0 }
{
    model=$1; input=$2+0; output=$3+0; cw=$4+0; cr=$5+0

    if      (model ~ /claude-opus-4-7/)    { pi=15.00; pcw=18.75; pcr=1.50; po=75.00 }
    else if (model ~ /claude-sonnet-4-6/)  { pi=3.00;  pcw=3.75;  pcr=0.30; po=15.00 }
    else if (model ~ /claude-haiku-4-5/)   { pi=0.80;  pcw=1.00;  pcr=0.08; po=4.00  }
    else                                   { pi=3.00;  pcw=3.75;  pcr=0.30; po=15.00 }

    regular = input - cw - cr
    if (regular < 0) regular = 0
    cost += (regular/1000000*pi) + (cw/1000000*pcw) + (cr/1000000*pcr) + (output/1000000*po)
}
END { printf "%.4f", cost }
')

[ -z "$total_cost" ] && exit 0

today=$(date +%Y-%m-%d)
now_ts=$(date +%s)
[ -f "$PERIOD_FILE" ] || echo '[]' > "$PERIOD_FILE"

TMP="${PERIOD_FILE}.tmp.$$"
(
    flock 9
    $JQ --arg sid "$session_id" --arg date "$today" --argjson cost "$total_cost" --argjson ts "$now_ts" '
        if any(.[]; .session_id == $sid) then
            map(if .session_id == $sid then . + {cost: $cost, timestamp: $ts} else . end)
        else
            . + [{session_id: $sid, date: $date, cost: $cost, timestamp: $ts}]
        end
    ' "$PERIOD_FILE" > "$TMP" 2>/dev/null \
        && mv "$TMP" "$PERIOD_FILE"
    rm -f "$TMP"
) 9>"${PERIOD_FILE}.lock"

# Clean up any temp files from the old approach
rm -f "/tmp/claude-costs/current-${session_id}"
