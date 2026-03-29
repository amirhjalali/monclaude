#!/bin/bash
# monclaude — a rich status line for Claude Code
# https://github.com/amirhjalali/monclaude
#
# Full mode (>= 80 cols):
#   Line 1: Model | context window bar | session cost
#   Line 2: 5hr usage | peak indicator | weekly usage | extra credits
# Compact mode (< 80 cols — phones, narrow terminals):
#   Single line: Model % cost · 5h % ↻reset · 7d % ↻reset
#
# Works on macOS and Linux. Detects terminal width via tmux, tput, or
# MONCLAUDE_COLS env var override.
set -f

input=$(cat)
if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Platform ───────────────────────────────────────────
is_mac=false
[ "$(uname)" = "Darwin" ] && is_mac=true

# ── Terminal width ─────────────────────────────────────
# MONCLAUDE_COLS override > tmux pane width > tput via /dev/tty > tput > 80
cols=${MONCLAUDE_COLS:-$(tmux display-message -p '#{pane_width}' 2>/dev/null \
    || tput cols </dev/tty 2>/dev/null \
    || tput cols 2>/dev/null \
    || echo 80)}
[ "$cols" -lt 20 ] && cols=40

# ── Colors ─────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
dim='\033[2m'
reset='\033[0m'

# ── Helpers ────────────────────────────────────────────

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

# Color by usage percentage: green < 50% < orange < 70% < yellow < 90% < red
pct_color() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf '%s' "$red"
    elif [ "$pct" -ge 70 ]; then printf '%s' "$yellow"
    elif [ "$pct" -ge 50 ]; then printf '%s' "$orange"
    else printf '%s' "$green"
    fi
}

build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local c
    c=$(pct_color $pct)
    local f="" e=""
    for ((i=0; i<filled; i++)); do f+="●"; done
    for ((i=0; i<empty; i++)); do e+="○"; done
    printf "${c}${f}${dim}${e}${reset}"
}

fmt_reset() {
    local iso="$1"
    [ -z "$iso" ] || [ "$iso" = "null" ] && return
    local stripped="${iso%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    local epoch
    if $is_mac; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -u -d "$stripped" +%s 2>/dev/null)
    fi
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

short_model() {
    local m="$1"
    m="${m/Claude /}"
    m="${m/Opus /Op}"
    m="${m/Sonnet /So}"
    m="${m/Haiku /Ha}"
    m="${m%% (*}"
    printf "%s" "$m"
}

# ── Session data ───────────────────────────────────────
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

# ── Usage API (cached 60s) ────────────────────────────
cache_file="/tmp/claude/statusline-usage-cache.json"
mkdir -p /tmp/claude

needs_refresh=true
if [ -f "$cache_file" ]; then
    if $is_mac; then
        cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    else
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
    fi
    now=$(date +%s)
    if [ $(( now - cache_mtime )) -lt 60 ]; then
        needs_refresh=false
    fi
fi

usage=""
if $needs_refresh; then
    token=""
    if $is_mac; then
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
            | grep -o '"accessToken":"[^"]*"' | head -1 \
            | sed 's/"accessToken":"//;s/"$//')
    else
        creds_file="${HOME}/.claude/.credentials.json"
        [ -f "$creds_file" ] && token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    fi
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
if [ -z "$usage" ] && [ -f "$cache_file" ]; then
    usage=$(cat "$cache_file" 2>/dev/null)
fi

# ── Peak detection ────────────────────────────────────
is_peak=false
pt_day=$(TZ=America/Los_Angeles date +%u)
pt_hour=$(TZ=America/Los_Angeles date +%-H)
if [ "$pt_day" -le 5 ] && [ "$pt_hour" -ge 5 ] && [ "$pt_hour" -lt 11 ]; then
    is_peak=true
fi

# ── Parse usage data ──────────────────────────────────
five_pct=0; week_pct=0; five_reset=""; week_reset=""
extra_enabled=false; extra_used=""; extra_limit=""
if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    five_pct=$(echo "$usage" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_reset_iso=$(echo "$usage" | jq -r '.five_hour.resets_at // empty')
    five_reset=$(fmt_reset "$five_reset_iso")

    week_pct=$(echo "$usage" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    week_reset_iso=$(echo "$usage" | jq -r '.seven_day.resets_at // empty')
    week_reset=$(fmt_reset "$week_reset_iso")

    extra_enabled=$(echo "$usage" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = "true" ]; then
        extra_used=$(echo "$usage" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$usage" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.0f", $1/100}')
    fi
fi

# ══════════════════════════════════════════════════════
# COMPACT MODE (< 80 cols — phones, VPS, narrow panes)
# One line, no bars — color-coded percentages
# Op4.6 7% ~$2.25 · 5h 7% in 2h · 7d 9% in 4d
# ══════════════════════════════════════════════════════

if [ "$cols" -lt 80 ]; then
    smodel=$(short_model "$model")
    pct_c=$(pct_color $pct_used)
    five_c=$(pct_color $five_pct)
    week_c=$(pct_color $week_pct)

    line="${blue}${smodel}${reset} ${pct_c}${pct_used}%${reset} ${dim}~${cost_fmt}${reset}"

    if [ -n "$usage" ]; then
        line+=" ${dim}·${reset} ${dim}5h ${reset}${five_c}${five_pct}%${reset}"
        [ -n "$five_reset" ] && line+=" ${dim}${five_reset}${reset}"
        $is_peak && line+=" ${yellow}PK${reset}"
        line+=" ${dim}· 7d ${reset}${week_c}${week_pct}%${reset}"
        [ -n "$week_reset" ] && line+=" ${dim}${week_reset}${reset}"
        if [ "$extra_enabled" = "true" ]; then
            line+=" ${cyan}+\$${extra_used}${reset}"
        fi
    fi

    printf "%b" "$line"
    exit 0
fi

# ══════════════════════════════════════════════════════
# FULL MODE (>= 80 cols — desktop / wide terminal)
# ══════════════════════════════════════════════════════

# LINE 1: Model | context bar | cost
line1="${blue}${model}${reset}"
line1+=" ${dim}|${reset} "
line1+="$(build_bar $pct_used 10) "
line1+="${cyan}$(fmt_tok $current)${dim}/${reset}$(fmt_tok $size)"
line1+=" ${dim}(${pct_used}%)${reset}"
line1+=" ${dim}|${reset} "
line1+="${dim}~${cost_fmt}${reset}"

# LINE 2: 5hr | weekly | extra
line2=""
if [ -n "$usage" ]; then
    line2="${white}5hr${reset} $(build_bar $five_pct 10) ${cyan}${five_pct}%${reset}"
    [ -n "$five_reset" ] && line2+=" ${dim}${five_reset}${reset}"
    $is_peak && line2+=" ${yellow}PEAK${reset}"
    line2+=" ${dim}|${reset} "
    line2+="${white}7d${reset} $(build_bar $week_pct 10) ${cyan}${week_pct}%${reset}"
    [ -n "$week_reset" ] && line2+=" ${dim}${week_reset}${reset}"
    if [ "$extra_enabled" = "true" ]; then
        line2+=" ${dim}|${reset} "
        line2+="${white}extra${reset} ${cyan}\$${extra_used}${dim}/\$${extra_limit}${reset}"
    fi
fi

printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"

exit 0
