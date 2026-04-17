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

# ── Effort level (from settings, not in status JSON) ──
effort=""
settings_file="${HOME}/.claude/settings.json"
if [ -f "$settings_file" ]; then
    effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
fi
effort_letter="" effort_color=""
case "$effort" in
    low)    effort_letter="L"; effort_color="$green" ;;
    medium) effort_letter="M"; effort_color="$orange" ;;
    high)   effort_letter="H"; effort_color="$yellow" ;;
    max)    effort_letter="X"; effort_color="$red" ;;
esac

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

# ── Usage API (cached) ────────────────────────────────
# Cache strategy:
#   - file contents = last VALID response (never overwritten by errors)
#   - file mtime    = last attempt (always bumped to enforce cooldown)
#   - mkdir lock    = mutex so only ONE session refreshes per TTL window
#
# Without the mutex, N concurrent sessions that hit the status line in the
# same ~100ms after the TTL expires will ALL see the stale cache and ALL
# fire the API, tripping rate limits in a burst. mkdir is atomic on POSIX,
# so we use it as a portable cross-process mutex (flock isn't built in on
# macOS).
#
# Error backoff: Anthropic's /api/oauth/usage endpoint has a known upstream
# bug (claude-code#30930, #31021, #31637) where it can get stuck returning
# HTTP 429 for hours regardless of retry cadence. When we detect that stuck
# state (cache file exists but has no valid data), stretch TTL to 30 min
# so we stop pressuring the broken endpoint. Normal 180s cadence resumes
# automatically once a successful response lands.
cache_file="/tmp/claude/statusline-usage-cache.json"
lock_dir="/tmp/claude/statusline-refresh.lock"
cache_ttl=180
error_ttl=1800
lock_stale_secs=5
mkdir -p /tmp/claude

# If the cache is currently in a stuck/error state, use the longer error TTL
effective_ttl=$cache_ttl
if [ -f "$cache_file" ]; then
    probe=$(cat "$cache_file" 2>/dev/null)
    if [ -z "$probe" ] || ! echo "$probe" | jq -e '.five_hour' >/dev/null 2>&1; then
        effective_ttl=$error_ttl
    fi
fi

needs_refresh=true
if [ -f "$cache_file" ]; then
    if $is_mac; then
        cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    else
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
    fi
    now=$(date +%s)
    if [ $(( now - cache_mtime )) -lt $effective_ttl ]; then
        needs_refresh=false
    fi
fi

# Try to acquire the refresh lock. If another session is already refreshing,
# we skip our own attempt and just read whatever's in the cache.
got_lock=false
if $needs_refresh; then
    # Clean stale lock from a session that was killed mid-refresh
    if [ -d "$lock_dir" ]; then
        if $is_mac; then
            lock_mtime=$(stat -f %m "$lock_dir" 2>/dev/null)
        else
            lock_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null)
        fi
        now=$(date +%s)
        if [ $(( now - lock_mtime )) -gt $lock_stale_secs ]; then
            rmdir "$lock_dir" 2>/dev/null
        fi
    fi
    if mkdir "$lock_dir" 2>/dev/null; then
        got_lock=true
        trap 'rmdir "$lock_dir" 2>/dev/null' EXIT HUP INT TERM
    fi
fi

if $got_lock; then
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
        if [ -n "$resp" ] && echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1; then
            # Fresh valid data — atomic write so concurrent readers never see
            # a partial file.
            tmp_file="${cache_file}.tmp.$$"
            if echo "$resp" > "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$cache_file" 2>/dev/null || rm -f "$tmp_file"
            fi
        else
            # Error, empty, or malformed — preserve last-good contents, just
            # bump mtime so we honor the cooldown before the next retry.
            if [ -f "$cache_file" ]; then
                touch "$cache_file" 2>/dev/null
            else
                : > "$cache_file"
            fi
        fi
    fi
    rmdir "$lock_dir" 2>/dev/null
    trap - EXIT HUP INT TERM
fi

# Read last-good cached response (only accept real usage payloads).
# If the cache file exists but contains no valid data, we've tried and
# failed to fetch — remember that so the status line can surface an
# error indicator instead of silently hiding the usage row.
usage=""
usage_error=false
if [ -f "$cache_file" ]; then
    cached=$(cat "$cache_file" 2>/dev/null)
    if [ -n "$cached" ] && echo "$cached" | jq -e '.five_hour' >/dev/null 2>&1; then
        usage="$cached"
    else
        usage_error=true
    fi
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
# Op4.6 H 7% ~$2.25 · 5h 7% in 2h · 7d 9% in 4d
# ══════════════════════════════════════════════════════

if [ "$cols" -lt 80 ]; then
    smodel=$(short_model "$model")
    pct_c=$(pct_color $pct_used)
    five_c=$(pct_color $five_pct)
    week_c=$(pct_color $week_pct)

    line="${blue}${smodel}${reset}"
    [ -n "$effort_letter" ] && line+=" ${effort_color}${effort_letter}${reset}"
    line+=" ${pct_c}${pct_used}%${reset} ${dim}~${cost_fmt}${reset}"

    if [ -n "$usage" ]; then
        line+=" ${dim}·${reset} ${dim}5h ${reset}${five_c}${five_pct}%${reset}"
        [ -n "$five_reset" ] && line+=" ${dim}${five_reset}${reset}"
        if $is_peak; then line+=" ${yellow}PK${reset}"; else line+=" ${green}OFF${reset}"; fi
        line+=" ${dim}· 7d ${reset}${week_c}${week_pct}%${reset}"
        [ -n "$week_reset" ] && line+=" ${dim}${week_reset}${reset}"
        if [ "$extra_enabled" = "true" ]; then
            line+=" ${cyan}+\$${extra_used}${reset}"
        fi
    elif $usage_error; then
        line+=" ${dim}·${reset} ${yellow}usage api down${reset} ${dim}(upstream)${reset}"
    fi

    printf "%b" "$line"
    exit 0
fi

# ══════════════════════════════════════════════════════
# FULL MODE (>= 80 cols — desktop / wide terminal)
# ══════════════════════════════════════════════════════

# LINE 1: Model [effort] | context bar | cost
line1="${blue}${model}${reset}"
[ -n "$effort_letter" ] && line1+=" ${effort_color}${effort_letter}${reset}"
line1+=" ${dim}|${reset} "
line1+="$(build_bar $pct_used 10) "
line1+="${cyan}$(fmt_tok $current)${dim}/${reset}$(fmt_tok $size)"
line1+=" ${dim}(${pct_used}%)${reset}"
line1+=" ${dim}|${reset} "
line1+="${dim}~${cost_fmt}${reset}"
line1+=" ${dim}|${reset} "
if $is_peak; then line1+="${yellow}PEAK${reset}"; else line1+="${green}OFF-PEAK${reset}"; fi

# LINE 2: 5hr | weekly | extra  (or rate-limit indicator)
line2=""
if [ -n "$usage" ]; then
    line2="${white}5hr${reset} $(build_bar $five_pct 10) ${cyan}${five_pct}%${reset}"
    [ -n "$five_reset" ] && line2+=" ${dim}${five_reset}${reset}"
    line2+=" ${dim}|${reset} "
    line2+="${white}7d${reset} $(build_bar $week_pct 10) ${cyan}${week_pct}%${reset}"
    [ -n "$week_reset" ] && line2+=" ${dim}${week_reset}${reset}"
    if [ "$extra_enabled" = "true" ]; then
        line2+=" ${dim}|${reset} "
        line2+="${white}extra${reset} ${cyan}\$${extra_used}${dim}/\$${extra_limit}${reset}"
    fi
elif $usage_error; then
    line2="${dim}usage api down upstream (HTTP 429, anthropics/claude-code#30930) — auto-retry${reset}"
fi

printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"

exit 0
