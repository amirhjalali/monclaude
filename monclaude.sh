#!/bin/bash
# monclaude — a rich status line for Claude Code
# https://github.com/amirhjalali/monclaude
#
# Line 1: Model | context window bar | session cost
# Line 2: 5hr usage | peak indicator | weekly usage | extra credits
set -f

input=$(cat)
if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
dim='\033[2m'
reset='\033[0m'

# ── Helpers ─────────────────────────────────────────────

# Format token counts: 500 → "500", 50000 → "50k", 1200000 → "1.2m"
fmt_tok() {
    local n=$1
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fm\", $n / 1000000}"
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.0fk\", $n / 1000}"
    else
        printf "%d" "$n"
    fi
}

# Color-coded progress bar: build_bar <percent> <width>
#   green < 50% < orange < 70% < yellow < 90% < red
build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local c
    if [ "$pct" -ge 90 ]; then c="$red"
    elif [ "$pct" -ge 70 ]; then c="$yellow"
    elif [ "$pct" -ge 50 ]; then c="$orange"
    else c="$green"
    fi
    local f="" e=""
    for ((i=0; i<filled; i++)); do f+="●"; done
    for ((i=0; i<empty; i++)); do e+="○"; done
    printf "${c}${f}${dim}${e}${reset}"
}

# Format ISO timestamp as relative duration: "in 2h 15m", "in 3d 5h"
fmt_reset() {
    local iso="$1"
    [ -z "$iso" ] || [ "$iso" = "null" ] && return
    local stripped="${iso%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    local epoch
    epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    [ -z "$epoch" ] && return
    local now=$(date +%s)
    local diff=$(( epoch - now ))
    [ "$diff" -le 0 ] && { printf "now"; return; }
    local days=$(( diff / 86400 ))
    local hours=$(( (diff % 86400) / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
        printf "in %dd %dh" "$days" "$hours"
    elif [ "$hours" -gt 0 ]; then
        printf "in %dh %dm" "$hours" "$mins"
    else
        printf "in %dm" "$mins"
    fi
}

# ── Extract session data from JSON input ────────────────
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tok + cache_create + cache_read ))
pct_used=$(( current * 100 / size ))

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_fmt=$(awk "BEGIN {printf \"$%.2f\", $cost}")

# ── LINE 1: Model | context bar | cost ─────────────────
line1="${blue}${model}${reset}"
line1+=" ${dim}|${reset} "
line1+="$(build_bar $pct_used 10) "
line1+="${cyan}$(fmt_tok $current)${dim}/${reset}$(fmt_tok $size)"
line1+=" ${dim}(${pct_used}%)${reset}"
line1+=" ${dim}|${reset} "
line1+="${dim}~${cost_fmt}${reset}"

# ── Usage API (cached 60s) ─────────────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
mkdir -p /tmp/claude

needs_refresh=true
if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    if [ $(( now - cache_mtime )) -lt 60 ]; then
        needs_refresh=false
    fi
fi

usage=""
if $needs_refresh; then
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | grep -o '"accessToken":"[^"]*"' | head -1 | sed 's/"accessToken":"//;s/"$//')
    if [ -n "$token" ]; then
        resp=$(curl -s --max-time 3 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$resp" ] && echo "$resp" | jq -e . >/dev/null 2>&1; then
            usage="$resp"
            echo "$resp" > "$cache_file"
        fi
    fi
fi
# Fallback to cache
if [ -z "$usage" ] && [ -f "$cache_file" ]; then
    usage=$(cat "$cache_file" 2>/dev/null)
fi

# ── Peak hours detection ───────────────────────────────
# Weekdays 5am-11am PT: session limits burn faster
is_peak=false
pt_day=$(TZ=America/Los_Angeles date +%u)  # 1=Mon, 7=Sun
pt_hour=$(TZ=America/Los_Angeles date +%-H)
if [ "$pt_day" -le 5 ] && [ "$pt_hour" -ge 5 ] && [ "$pt_hour" -lt 11 ]; then
    is_peak=true
fi

# ── LINE 2: 5hr | weekly | extra ──────────────────────
line2=""
if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    five_pct=$(echo "$usage" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_reset_iso=$(echo "$usage" | jq -r '.five_hour.resets_at // empty')
    five_reset=$(fmt_reset "$five_reset_iso")

    week_pct=$(echo "$usage" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    week_reset_iso=$(echo "$usage" | jq -r '.seven_day.resets_at // empty')
    week_reset=$(fmt_reset "$week_reset_iso")

    line2="${white}5hr${reset} $(build_bar $five_pct 10) ${cyan}${five_pct}%${reset}"
    [ -n "$five_reset" ] && line2+=" ${dim}${five_reset}${reset}"
    if $is_peak; then
        line2+=" ${yellow}PEAK${reset}"
    fi
    line2+=" ${dim}|${reset} "
    line2+="${white}7d${reset} $(build_bar $week_pct 10) ${cyan}${week_pct}%${reset}"
    [ -n "$week_reset" ] && line2+=" ${dim}${week_reset}${reset}"

    # Extra usage (pay-as-you-go) if enabled
    extra_enabled=$(echo "$usage" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = "true" ]; then
        extra_used=$(echo "$usage" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$usage" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.0f", $1/100}')
        extra_pct=$(echo "$usage" | jq -r '.extra_usage.utilization // 0' | awk '{printf "%.0f", $1}')
        line2+=" ${dim}|${reset} "
        line2+="${white}extra${reset} ${cyan}\$${extra_used}${dim}/\$${extra_limit}${reset}"
    fi
fi

# ── Output ─────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"

exit 0
