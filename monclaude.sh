#!/bin/bash
# monclaude — a rich status line for Claude Code
# https://github.com/amirhjalali/monclaude
#
# Full mode (>= 80 cols):
#   Line 1: [folder branch |] Model | context window bar | session cost
#   Line 2: [account |] 5hr usage | weekly usage | extra credits [| other accounts]
# Compact mode (< 80 cols — phones, narrow terminals):
#   Single line: Model % cost · 5h % ↻reset · 7d % ↻reset
#
# Works on macOS and Linux. Detects terminal width via tmux, tput, or
# MONCLAUDE_COLS env var override.
set -f

# ── Subcommand dispatch ────────────────────────────────
# Recognized subcommands must be handled WITHOUT reading stdin (cat would
# block on a TTY). We only set flags here; the commands run further down,
# after the helper functions and cache config they depend on are defined.
cmd_is_usage=false
cmd_is_help=false
case "${1:-}" in
    usage)            cmd_is_usage=true ;;
    -h|--help|help)   cmd_is_help=true ;;
esac

# Only the status-line path consumes session JSON from stdin.
if [ "$cmd_is_usage" = false ] && [ "$cmd_is_help" = false ]; then
    input=$(cat)
    if [ -z "$input" ]; then
        printf "Claude"
        exit 0
    fi
fi

# ── Platform ───────────────────────────────────────────
is_mac=false
[ "$(uname)" = "Darwin" ] && is_mac=true

# ── Terminal width ─────────────────────────────────────
# MONCLAUDE_COLS override > tmux pane width > tput via /dev/tty > tput > 80
cols=${MONCLAUDE_COLS:-$(tmux display-message -p '#{pane_width}' 2>/dev/null \
    || (tput cols </dev/tty) 2>/dev/null \
    || tput cols 2>/dev/null \
    || echo 80)}
[ "$cols" -lt 20 ] && cols=40

# ── Colors ─────────────────────────────────────────────
# Cool & Calm palette. The tier names (green/orange/yellow/red) denote usage
# *tiers* low→max, not literal hues — the ramp stays cool until you near a
# limit, then warms to alert.
blue='\033[38;2;138;162;232m'    # model name — slate-indigo
orange='\033[38;2;229;192;123m'  # 50-69% tier — soft gold
green='\033[38;2;86;182;194m'    # 0-49% tier — teal (calm)
cyan='\033[38;2;86;182;194m'     # numbers, cost, extra — soft teal
red='\033[38;2;224;108;117m'     # 90%+ tier — soft red
yellow='\033[38;2;232;155;90m'   # 70-89% tier — amber
white='\033[38;2;200;205;214m'   # labels — cool gray
nudge='\033[38;2;152;195;121m'   # unused-quota nudge — soft green
dim='\033[2m'
bar_track='\033[48;2;52;56;64m'  # cool slate track
bar_text='\033[38;2;245;245;245m'
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

# Background-color version of pct_color, for the filled portion of a bar.
pct_color_bg() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf '%s' '\033[48;2;165;72;80m'     # soft red
    elif [ "$pct" -ge 70 ]; then printf '%s' '\033[48;2;170;105;55m'  # amber
    elif [ "$pct" -ge 50 ]; then printf '%s' '\033[48;2;160;128;65m'  # gold
    else printf '%s' '\033[48;2;46;112;122m'                          # teal
    fi
}

# Solid bar with the "NN%" label centered *inside* the fill, bracketed.
# The number rides on the bar instead of sitting beside it, so the whole
# gauge is more compact than the old ●○ dots.
build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local label="${pct}%"
    local lablen=${#label}
    local pad_left=$(( (width - lablen) / 2 ))
    [ "$pad_left" -lt 0 ] && pad_left=0
    local pad_right=$(( width - pad_left - lablen ))
    [ "$pad_right" -lt 0 ] && pad_right=0
    local inner
    inner=$(printf "%*s%s%*s" "$pad_left" "" "$label" "$pad_right" "")
    inner=${inner:0:width}
    local left="${inner:0:filled}"
    local right="${inner:filled}"
    local bg_fill
    bg_fill=$(pct_color_bg "$pct")
    printf "%b" "${dim}[${reset}${bg_fill}${bar_text}${left}${bar_track}${bar_text}${right}${reset}${dim}]${reset}"
}

# Seconds from now until an ISO-8601 timestamp (negative if already past,
# empty on parse failure). Shared by fmt_reset and the unused-quota nudge.
secs_until() {
    local iso="$1"
    [ -z "$iso" ] || [ "$iso" = "null" ] && return
    # Unix epoch seconds (Codex reports resets this way).
    case "$iso" in
        *[!0-9]*) ;;
        *) printf "%d" "$(( iso - $(date +%s) ))"; return ;;
    esac
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
    printf "%d" "$(( epoch - $(date +%s) ))"
}

fmt_reset() {
    local diff
    diff=$(secs_until "$1")
    [ -z "$diff" ] && return
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

# Per-model scoped weekly caps (e.g. a separate Fable limit) live in the
# `limits` array of the usage response, not the top-level five_hour/seven_day
# fields. Reads the usage JSON on stdin, emits one TSV line per scoped entry:
# name <TAB> percent <TAB> resets_at <TAB> is_active
scoped_limits_tsv() {
    jq -r '
        (.limits // [])[]
        | select(.kind == "weekly_scoped")
        | [ (.scope.model.display_name // .scope.surface // "scoped"),
            ((.percent // 0) | round | tostring),
            (.resets_at // ""),
            ((.is_active // false) | tostring) ]
        | @tsv' 2>/dev/null
}

# Codex (OpenAI) rate limits. Codex has no usage endpoint we can poll, but it
# logs a rate_limits snapshot in every token_count event of its session
# rollouts (~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl). Take the newest
# snapshot per limit_id from the most recent rollouts and emit one TSV line
# per window: name <TAB> window <TAB> percent <TAB> resets_at_epoch
# A window whose reset has passed has rolled over, so it reads 0%.
# The main "codex" limit is always shown; others (e.g. Spark) only when used.
# Result is cached for codex_ttl seconds to keep renders cheap.
codex_limits_tsv() {
    [ -n "${MONCLAUDE_NO_CODEX:-}" ] && return
    local sessions="${CODEX_HOME:-$HOME/.codex}/sessions"
    [ -d "$sessions" ] || return
    local out="$cache_dir/codex-limits.tsv" mtime now
    now=$(date +%s)
    if [ -f "$out" ]; then
        if $is_mac; then mtime=$(stat -f %m "$out" 2>/dev/null)
        else mtime=$(stat -c %Y "$out" 2>/dev/null); fi
        if [ $(( now - ${mtime:-0} )) -lt "$codex_ttl" ]; then
            cat "$out"; return
        fi
    fi
    local files f tmp="$out.tmp.$$"
    # Newest 5 by mtime are enough. Not by name: names carry the session's
    # start time, and a long-running or resumed session keeps writing to its
    # old rollout, which would drop out of a by-name pick and go stale.
    files=$(find "$sessions" -name 'rollout-*.jsonl' -mtime -14 2>/dev/null)
    [ -n "$files" ] || return
    # shellcheck disable=SC2086
    files=$(ls -t $files 2>/dev/null | head -5)
    {
        for f in $files; do
            grep -h '"rate_limits"' "$f" 2>/dev/null | tail -20
        done
    } | jq -rs --argjson now "$now" '
        [ .[] | select(.payload.rate_limits.limit_id?)
              | {ts: .timestamp, rl: .payload.rate_limits} ]
        | group_by(.rl.limit_id) | map(max_by(.ts).rl)
        | sort_by(if .limit_id == "codex" then 0 else 1 end)
        | .[]
        | (if .limit_id == "codex" then "Codex" else (.limit_name // .limit_id) end) as $name
        | .limit_id as $id
        | (.primary, .secondary) | select(. != null)
        | (if (.resets_at // 0) > 0 and .resets_at <= $now then 0
           else ((.used_percent // 0) | round) end) as $p
        | select($id == "codex" or $p > 0)
        | [ $name,
            (if .window_minutes == 300 then "5h"
             elif .window_minutes == 10080 then "7d"
             elif (.window_minutes // 0) >= 1440 then "\((.window_minutes / 1440) | floor)d"
             else "\((.window_minutes // 0) / 60 | floor)h" end),
            ($p | tostring),
            ((.resets_at // "") | tostring) ]
        | @tsv' 2>/dev/null > "$tmp"
    mv "$tmp" "$out" 2>/dev/null || rm -f "$tmp"
    cat "$out" 2>/dev/null
}

# ── Cache config ──────────────────────────────────────
# Shared by the status-line path and ensure_usage_cache (defined below).
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
cache_dir="${MONCLAUDE_CACHE_DIR:-/tmp/claude}"
cache_file="$cache_dir/statusline-usage-cache.json"
lock_dir="$cache_dir/statusline-refresh.lock"
cache_ttl=180
live_ttl=600
codex_ttl=60
live_file="$cache_dir/statusline-live-limits.json"
error_ttl=1800
lock_stale_secs=5

# True when stdin is a usage payload. Not `jq -e .five_hour`: the API sends
# five_hour: null when no 5h window is active, and that check took every such
# 200 for an error, freezing the cache on its last pre-null response.
is_usage_json() {
    jq -e 'type == "object" and (has("five_hour") or has("seven_day"))' >/dev/null 2>&1
}

# True when the usage payload on stdin says the account has a 5h limit.
# Accounts without one (e.g. verified Ultra) get five_hour: null and no
# "session" entry in the limits array. A null five_hour alone is not proof:
# capped accounts can see it between windows, and responses without a
# limits array (live-only data, older API shape) count as capped.
has_five_hour_limit() {
    jq -e '.five_hour != null or (has("limits") | not)
           or any(.limits[]?; .kind == "session")' >/dev/null 2>&1
}
mkdir -p "$cache_dir"

# ── Other accounts (optional pools file) ───────────────
# If you have several accounts (a second Claude login, Codex, Gemini, ...),
# whatever tracks them can write their limits to one JSON file. monclaude
# then names the account this session is on (and its rule, e.g. "work
# only"), and shows the other accounts on a third line. It only reads the
# file: no extra logins, probes or API calls. Format: README "Other accounts".
# MONCLAUDE_POOLS sets the path; MONCLAUDE_NO_POOLS=1 turns it off.
pools_file="${MONCLAUDE_POOLS:-$HOME/.config/monclaude/pools.json}"
pools_stale_secs=10800
us=$'\x1f'

# First 8 hex of sha256(email) of the Claude account this session uses,
# from Claude Code's own config. Cached until that file changes (a /login
# to another account rewrites it), since ~/.claude.json can be large.
session_account_id() {
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"
    [ -f "$cfg" ] || return
    local out email id
    out="$cache_dir/account-id-$(printf '%s' "$cfg" | cksum | cut -d' ' -f1)"
    if [ -s "$out" ] && [ "$out" -nt "$cfg" ]; then cat "$out"; return; fi
    email=$(jq -r '.oauthAccount.emailAddress // empty' "$cfg" 2>/dev/null)
    [ -z "$email" ] && return
    if command -v shasum >/dev/null 2>&1; then
        id=$(printf '%s' "$email" | shasum -a 256 | cut -c1-8)
    else
        id=$(printf '%s' "$email" | sha256sum | cut -c1-8)
    fi
    printf '%s' "$id" > "$out.tmp.$$" 2>/dev/null && mv "$out.tmp.$$" "$out" 2>/dev/null
    printf '%s' "$id"
}

# One line per account in the pools file, headline (first) window only:
# me|other, label, kind, rule, percent ("?" if unknown), resets_at, as_of,
# separated by $us (ASCII unit separator: unlike tabs, `read` does not merge
# empty fields). Backslashes and control characters are dropped, since the
# text is printed with %b.
# Arg 1: this session's account id ("" if unknown: every account is "other").
pools_tsv() {
    [ -n "${MONCLAUDE_NO_POOLS:-}" ] && return
    [ -f "$pools_file" ] || return
    jq -r --arg me "$1" '
        (.as_of // "") as $top
        | (.pools // [])[]
        | select((.windows // []) | length > 0)
        | .windows[0] as $w
        | [ (if $me != "" and .id == $me then "me" else "other" end),
            (.label // .id // "?"), (.kind // ""), (.rule // ""),
            (if ($w.used_pct | type) == "number" then ($w.used_pct | round | tostring) else "?" end),
            ($w.resets_at // ""), (.as_of // $top) ]
        | map(tostring | gsub("[\\\\[:cntrl:]]"; "")) | join("\u001f")' "$pools_file" 2>/dev/null
}

# Seconds since the pools file's as_of (empty if unknown).
pools_age_secs() {
    local at age
    at=$(jq -r '.as_of // empty' "$pools_file" 2>/dev/null)
    [ -z "$at" ] && return
    age=$(secs_until "$at")
    [ -n "$age" ] && printf '%d' "$(( -age ))"
}

# ── Subcommands (agent-facing) ─────────────────────────
cmd_help() {
    cat <<'EOF'
monclaude — a rich status line for Claude Code

As a status line: configure it as your Claude Code statusLine command; it reads
session JSON on stdin and renders model / context / cost / rate-limit info.

Subcommands (for humans and agents):
  monclaude usage          Print current Claude usage as one human-readable line.
  monclaude usage --json   Print current usage as JSON (for agents/automation).
  monclaude --help         Show this help.

usage --json fields:
  five_hour / seven_day : { utilization, headroom, resets_at, resets_in_seconds }
                          five_hour is null when the account has no 5h limit
  weekly_scoped         : [ { scope, utilization, headroom, resets_at,
                              resets_in_seconds, severity, is_active } ]
                          per-model weekly caps (e.g. Fable) — [] if none
  codex                 : [ { limit, window, utilization, headroom, resets_at
                              (epoch), resets_in_seconds } ] — from local
                          Codex session logs; [] if Codex isn't used here
  extra_usage           : { enabled, used_usd, limit_usd }
  account               : { id, label, rule } — this session's account, from
                          the pools file (null without one)
  others                : [ { label, kind, rule, utilization, resets_at } ]
                          the pools file's other accounts ([] without one)
  data_age_seconds, stale, error
Exit status: 0 = usable numbers (act when stale=false); 1 = no data (error=true).

The five_hour/seven_day numbers describe the Claude account tied to your local
OAuth token. The codex array is read from ~/.codex (as of Codex's last turn);
set MONCLAUDE_NO_CODEX=1 to hide it.

account / others come from an optional pools file
(~/.config/monclaude/pools.json, or $MONCLAUDE_POOLS) that lists all your
accounts; both are null / [] without one. See README "Other accounts".

https://github.com/amirhjalali/monclaude
EOF
}

# Make $cache_file current: reuse the live response if it is within TTL,
# otherwise fetch under a mkdir mutex with the known-429 error backoff.
# Shared by the status line and `monclaude usage` so there is one fetch path.
ensure_usage_cache() {
    local effective_ttl=$cache_ttl
    if [ -f "$cache_file" ]; then
        local probe
        probe=$(cat "$cache_file" 2>/dev/null)
        if [ -z "$probe" ] || ! echo "$probe" | is_usage_json; then
            effective_ttl=$error_ttl
        fi
    fi

    local needs_refresh=true now
    if [ -f "$cache_file" ]; then
        local cache_mtime
        if $is_mac; then cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
        else cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null); fi
        now=$(date +%s)
        if [ $(( now - cache_mtime )) -lt $effective_ttl ]; then
            needs_refresh=false
        fi
    fi
    $needs_refresh || return 0

    # Clear a stale lock left by a session killed mid-refresh.
    if [ -d "$lock_dir" ]; then
        local lock_mtime
        if $is_mac; then lock_mtime=$(stat -f %m "$lock_dir" 2>/dev/null)
        else lock_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null); fi
        now=$(date +%s)
        if [ $(( now - lock_mtime )) -gt $lock_stale_secs ]; then
            rmdir "$lock_dir" 2>/dev/null
        fi
    fi

    # Only one session refreshes per TTL window; others read the cache.
    mkdir "$lock_dir" 2>/dev/null || return 0
    trap 'rmdir "$lock_dir" 2>/dev/null' EXIT HUP INT TERM

    local token=""
    if $is_mac; then
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
            | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    else
        local creds_file="${HOME}/.claude/.credentials.json"
        [ -f "$creds_file" ] && token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
    fi

    if [ -n "$token" ]; then
        local resp
        resp=$(curl -s --max-time 3 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$resp" ] && echo "$resp" | is_usage_json; then
            # Stamp fetched_at so `usage` can report true data age even after an
            # error-state touch bumps the file mtime.
            local tmp_file="${cache_file}.tmp.$$"
            if echo "$resp" | jq --argjson t "$(date +%s)" '. + {fetched_at: $t}' > "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$cache_file" 2>/dev/null || rm -f "$tmp_file"
            fi
        else
            # Error/empty/malformed — keep last-good contents, bump mtime for cooldown.
            if [ -f "$cache_file" ]; then touch "$cache_file" 2>/dev/null
            else : > "$cache_file"; fi
        fi
    fi

    rmdir "$lock_dir" 2>/dev/null
    trap - EXIT HUP INT TERM
}

# Live 5h/7d limits, in the usage-API shape. Claude Code reads them from the
# rate-limit headers of every reply and passes them to the status line as
# .rate_limits, so they are current and immune to the /api/oauth/usage 429s.
# Reads status JSON on stdin; prints nothing when the field is absent (older
# Claude Code, API-key users, or before the session's first reply).
live_limits_from_input() {
    jq -c --argjson now "$(date +%s)" '
        def win: if . == null then null else
            { utilization: (.used_percentage // 0),
              resets_at: (.resets_at | if type == "number" then (floor | todate) else . end) } end;
        (.rate_limits // {})
        | select(.five_hour != null or .seven_day != null)
        | { five_hour: (.five_hour | win), seven_day: (.seven_day | win),
            fetched_at: $now, source: "session" }' 2>/dev/null
}

# Overlay live 5h/7d (arg 2) on the API response (arg 1), keeping the API's
# extras (per-model limits, extra credits). Either may be empty. When both
# exist, the live windows win only if they are the newer observation.
merge_usage() {
    local api="$1" live="$2"
    if [ -z "$live" ]; then printf '%s' "$api"; return; fi
    if [ -z "$api" ]; then printf '%s' "$live"; return; fi
    jq -cn --argjson a "$api" --argjson l "$live" '
        if ($l.fetched_at // 0) >= ($a.fetched_at // 0)
        then $a + { five_hour: ($l.five_hour // $a.five_hour),
                    seven_day: ($l.seven_day // $a.seven_day),
                    fetched_at: $l.fetched_at }
        else $a end' 2>/dev/null || printf '%s' "$api"
}

# Last live snapshot written by a status-line render, if still recent.
recent_live_limits() {
    [ -f "$live_file" ] || return
    local snap age
    snap=$(cat "$live_file" 2>/dev/null)
    age=$(( $(date +%s) - $(echo "$snap" | jq -r '.fetched_at // 0' 2>/dev/null || echo 0) ))
    [ "$age" -le "$live_ttl" ] && printf '%s' "$snap"
}

# Codex windows as a JSON array for `usage --json` ([] when none).
codex_limits_json() {
    local now="$1"
    codex_limits_tsv | jq -Rsc --argjson now "$now" '
        [ split("\n")[] | select(length > 0) | split("\t")
          | { limit: .[0], window: .[1],
              utilization: (.[2] | tonumber), headroom: (100 - (.[2] | tonumber)),
              resets_at: (if .[3] == "" then null else (.[3] | tonumber) end),
              resets_in_seconds: (if .[3] == "" then null else ((.[3] | tonumber) - $now) end) } ]' 2>/dev/null \
        || printf '[]'
}

# Codex windows as one human line for `monclaude usage` (nothing when none).
codex_usage_line() {
    local line="" c_name c_win c_pct c_reset r
    while IFS=$'\t' read -r c_name c_win c_pct c_reset; do
        [ -z "$c_name" ] && continue
        [ -n "$line" ] && line+=" · "
        line+="${c_name} ${c_win} ${c_pct}%"
        r=$(fmt_reset "$c_reset")
        [ -n "$r" ] && line+=" (resets $r)"
    done <<< "$(codex_limits_tsv)"
    [ -n "$line" ] && printf '%s\n' "$line"
    return 0
}

# Emit current usage as JSON (mode=json) or one human line (mode=plain).
cmd_usage() {
    local mode="${1:-plain}"
    # A recent live snapshot covers 5h/7d, so the API is only needed for the
    # extras and can be polled far less often.
    local live
    live=$(recent_live_limits)
    [ -n "$live" ] && cache_ttl=$live_ttl
    ensure_usage_cache

    local cached=""
    [ -f "$cache_file" ] && cached=$(cat "$cache_file" 2>/dev/null)
    echo "$cached" | is_usage_json || cached=""
    cached=$(merge_usage "$cached" "$live")
    if [ -z "$cached" ] || ! echo "$cached" | jq -e '.five_hour // .seven_day' >/dev/null 2>&1; then
        if [ "$mode" = json ]; then
            jq -n --argjson cx "$(codex_limits_json "$(date +%s)")" '{five_hour:null,seven_day:null,weekly_scoped:[],codex:$cx,extra_usage:{enabled:false,used_usd:null,limit_usd:null},data_age_seconds:null,stale:true,error:true}'
        else
            printf 'usage api down (upstream)\n'
            codex_usage_line
        fi
        return 1
    fi

    local now five_util week_util five_iso week_iso fetched_at
    now=$(date +%s)
    five_util=$(echo "$cached" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    # Hide 5h only for accounts that have no 5h limit at all.
    local five_known=true
    echo "$cached" | has_five_hour_limit || five_known=false
    week_util=$(echo "$cached" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    five_iso=$(echo "$cached" | jq -r '.five_hour.resets_at // empty')
    week_iso=$(echo "$cached" | jq -r '.seven_day.resets_at // empty')
    fetched_at=$(echo "$cached" | jq -r '.fetched_at // empty')

    local five_secs week_secs data_age stale
    five_secs=$(secs_until "$five_iso")
    week_secs=$(secs_until "$week_iso")
    stale=false
    if [ -n "$fetched_at" ]; then
        data_age=$(( now - fetched_at ))
        [ "$data_age" -gt "$cache_ttl" ] && stale=true
    else
        data_age=""        # unknown age → treat as stale (conservative)
        stale=true
    fi

    local extra_enabled extra_used extra_limit
    extra_enabled=$(echo "$cached" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = true ]; then
        extra_used=$(echo "$cached" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$cached" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.0f", $1/100}')
    else
        extra_used=null
        extra_limit=null
    fi

    # Per-model scoped weekly caps (e.g. Fable) from the `limits` array.
    # resets_in_seconds is computed in jq; the try/catch tolerates timestamps
    # it can't parse (emits null rather than failing the whole array).
    local scoped_json
    scoped_json=$(echo "$cached" | jq -c --argjson now "$now" '
        [ (.limits // [])[]
          | select(.kind == "weekly_scoped")
          | ((.percent // 0) | round) as $p
          | { scope: (.scope.model.display_name // .scope.surface // "scoped"),
              utilization: $p,
              headroom: (100 - $p),
              resets_at: .resets_at,
              resets_in_seconds: (try ((.resets_at | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601) - $now) catch null),
              severity: .severity,
              is_active: (.is_active // false) } ]' 2>/dev/null)
    [ -z "$scoped_json" ] && scoped_json="[]"
    local codex_json
    codex_json=$(codex_limits_json "$now")

    # This session's account and the other accounts, from the pools file.
    local my_id pools acct_json others_json
    my_id=$(session_account_id)
    pools=$(pools_tsv "$my_id")
    acct_json=$(printf '%s\n' "$pools" | jq -Rsc --arg id "$my_id" '
        [ split("\n")[] | select(startswith("me\u001f")) | split("\u001f") ] | first
        | if . == null then null else {id: $id, label: .[1], rule: (if .[3] == "" then null else .[3] end)} end' 2>/dev/null)
    [ -z "$acct_json" ] && acct_json=null
    others_json=$(printf '%s\n' "$pools" | jq -Rsc '
        [ split("\n")[] | select(startswith("other\u001f")) | split("\u001f")
          | {label: .[1], kind: .[2], rule: (if .[3] == "" then null else .[3] end),
             utilization: (.[4] | tonumber? // null), resets_at: (if .[5] == "" then null else .[5] end),
             as_of: (if .[6] == "" then null else .[6] end)} ]' 2>/dev/null)
    [ -z "$others_json" ] && others_json="[]"

    if [ "$mode" = json ]; then
        jq -n \
            --argjson fk "$five_known" \
            --argjson fu "$five_util" --argjson fh "$(( 100 - five_util ))" \
            --arg     fr "$five_iso"  --argjson fs "${five_secs:-null}" \
            --argjson wu "$week_util" --argjson wh "$(( 100 - week_util ))" \
            --arg     wr "$week_iso"  --argjson ws "${week_secs:-null}" \
            --argjson sc "$scoped_json" --argjson cx "$codex_json" \
            --argjson ee "$extra_enabled" --argjson eu "$extra_used" --argjson el "$extra_limit" \
            --argjson da "${data_age:-null}" --argjson st "$stale" \
            --argjson acct "$acct_json" --argjson oth "$others_json" \
            '{
               five_hour:   (if $fk then {utilization: $fu, headroom: $fh, resets_at: (if $fr=="" then null else $fr end), resets_in_seconds: $fs} else null end),
               seven_day:   {utilization: $wu, headroom: $wh, resets_at: (if $wr=="" then null else $wr end), resets_in_seconds: $ws},
               weekly_scoped: $sc,
               codex: $cx,
               extra_usage: {enabled: $ee, used_usd: $eu, limit_usd: $el},
               account: $acct,
               others: $oth,
               data_age_seconds: $da,
               stale: $st,
               error: false
             }'
    else
        local line="" fr wr
        fr=$(fmt_reset "$five_iso")
        wr=$(fmt_reset "$week_iso")
        if $five_known; then
            line="5h ${five_util}%"
            [ -n "$fr" ] && line="$line (resets $fr)"
            line="$line · "
        fi
        line="${line}7d ${week_util}%"
        [ -n "$wr" ] && line="$line (resets $wr)"
        local s_name s_pct s_iso sr
        while IFS=$'\t' read -r s_name s_pct s_iso _; do
            [ -z "$s_name" ] && continue
            line="$line · ${s_name} ${s_pct}%"
            sr=$(fmt_reset "$s_iso")
            [ -n "$sr" ] && line="$line (resets $sr)"
        done <<< "$(echo "$cached" | scoped_limits_tsv)"
        local p_who p_label p_kind p_rule p_pct p_iso me="" oth="" pr
        while IFS="$us" read -r p_who p_label p_kind p_rule p_pct p_iso _; do
            [ -z "$p_who" ] && continue
            if [ "$p_who" = me ]; then
                me="$p_label"; [ -n "$p_rule" ] && me="$me ($p_rule)"
            else
                [ -n "$oth" ] && oth="$oth · "
                oth="${oth}${p_label} ${p_pct}%"
                [ -n "$p_rule" ] && oth="$oth ($p_rule)"
                pr=$(fmt_reset "$p_iso"); [ -n "$pr" ] && oth="$oth resets $pr"
            fi
        done <<< "$pools"
        [ -n "$me" ] && line="${me}: ${line}"
        printf '%s\n' "$line"
        codex_usage_line
        if [ -n "$oth" ]; then
            local oage; oage=$(pools_age_secs)
            [ -n "$oage" ] && [ "$oage" -gt "$pools_stale_secs" ] && oth="$oth ($(( oage / 3600 ))h old)"
            printf 'others: %s\n' "$oth"
        fi
    fi
    return 0
}

if [ "$cmd_is_help" = true ]; then
    cmd_help
    exit 0
fi

if [ "$cmd_is_usage" = true ]; then
    if [ "${2:-}" = "--json" ]; then cmd_usage json; else cmd_usage plain; fi
    exit $?
fi

# ── Effort level ──
# Claude Code sends the session's live effort as .effort.level (it follows
# /effort and model switches, and is absent for models without effort).
# Older versions send neither .effort nor .thinking, so only then fall back
# to the saved settings default (which misses session-only /effort changes).
effort=$(echo "$input" | jq -r '.effort.level // empty' 2>/dev/null)
if [ -z "$effort" ] && ! echo "$input" | jq -e 'has("effort") or has("thinking")' >/dev/null 2>&1; then
    settings_file="${HOME}/.claude/settings.json"
    if [ -f "$settings_file" ]; then
        effort=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null)
    fi
fi
# Distinct cool→warm ramp, one hue per level (not the usage palette — effort
# is depth-of-thought, not a danger scale). Var names denote tiers, not hues:
# $green=teal, $nudge=soft-green, $orange=gold, $yellow=amber, $red=red.
effort_label="" effort_color=""
case "$effort" in
    low)    effort_label="low";   effort_color="$green" ;;   # teal
    medium) effort_label="med";   effort_color="$nudge" ;;   # soft-green
    high)   effort_label="high";  effort_color="$orange" ;;  # gold
    xhigh)  effort_label="xhigh"; effort_color="$yellow" ;;  # amber
    max)    effort_label="max";   effort_color="$red" ;;     # red
esac

# ── Session data ───────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

# Where this session is: folder name and git branch. Helps tell a dozen
# open sessions apart. MONCLAUDE_NO_LOCATION=1 turns it off.
loc_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
loc_folder=""
loc_branch=""
if [ -z "${MONCLAUDE_NO_LOCATION:-}" ] && [ -n "$loc_dir" ] && [ -d "$loc_dir" ]; then
    if [ "$loc_dir" = "$HOME" ]; then loc_folder="~"; else loc_folder=$(basename "$loc_dir"); fi
    loc_branch=$(git -C "$loc_dir" symbolic-ref --quiet --short HEAD 2>/dev/null \
        || git -C "$loc_dir" rev-parse --short HEAD 2>/dev/null)
    [ "${#loc_branch}" -gt 24 ] && loc_branch="${loc_branch:0:23}…"
fi

input_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tok + cache_create + cache_read ))
pct_used=$(( current * 100 / size ))

cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
cost_fmt=$(awk "BEGIN {printf \"$%.2f\", $cost}")

# ── Usage: live from Claude Code, API for the extras ──
# Snapshot the live limits for `monclaude usage`, and relax API polling
# while they are flowing (the API then only supplies Fable/extra credits).
live_limits=$(echo "$input" | live_limits_from_input)
if [ -n "$live_limits" ]; then
    cache_ttl=$live_ttl
    tmp_l="$live_file.tmp.$$"
    if printf '%s\n' "$live_limits" > "$tmp_l" 2>/dev/null; then
        mv "$tmp_l" "$live_file" 2>/dev/null || rm -f "$tmp_l"
    fi
fi
ensure_usage_cache

# Read last-good cached response (only accept real usage payloads).
# If the cache file exists but contains no valid data, we've tried and
# failed to fetch — remember that so the status line can surface an
# error indicator instead of silently hiding the usage row.
usage=""
usage_error=false
if [ -f "$cache_file" ]; then
    cached=$(cat "$cache_file" 2>/dev/null)
    if [ -n "$cached" ] && echo "$cached" | is_usage_json; then
        usage="$cached"
    else
        usage_error=true
    fi
fi
# Live 5h/7d override the API's; with them, an API outage only hides extras.
if [ -n "$live_limits" ]; then
    usage=$(merge_usage "$usage" "$live_limits")
    usage_error=false
fi

# ── Parse usage data ──────────────────────────────────
five_pct=0; week_pct=0; five_reset=""; week_reset=""; five_known=false
extra_enabled=false; extra_used=""; extra_limit=""
if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    five_pct=$(echo "$usage" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_reset_iso=$(echo "$usage" | jq -r '.five_hour.resets_at // empty')
    five_reset=$(fmt_reset "$five_reset_iso")
    echo "$usage" | has_five_hour_limit && five_known=true

    week_pct=$(echo "$usage" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    week_reset_iso=$(echo "$usage" | jq -r '.seven_day.resets_at // empty')
    week_reset=$(fmt_reset "$week_reset_iso")

    extra_enabled=$(echo "$usage" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra_enabled" = "true" ]; then
        extra_used=$(echo "$usage" | jq -r '.extra_usage.used_credits // 0' | awk '{printf "%.2f", $1/100}')
        extra_limit=$(echo "$usage" | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.0f", $1/100}')
    fi
fi

# Per-model scoped weekly caps (e.g. Fable) — TSV lines, empty if none.
scoped_limits=""
[ -n "$usage" ] && scoped_limits=$(echo "$usage" | scoped_limits_tsv)

# Codex windows — TSV lines, empty if Codex isn't used on this machine.
codex_limits=$(codex_limits_tsv)

# This session's account and the other accounts (optional pools file).
# A Codex reading under 3 h old replaces the local one: Codex's logs are
# only as new as its last turn on this machine. MONCLAUDE_NO_CODEX=1 hides
# Codex from both sources.
me_label="" me_rule="" others="" pools_stale=false
if [ -z "${MONCLAUDE_NO_POOLS:-}" ] && [ -f "$pools_file" ]; then
    pools=$(pools_tsv "$(session_account_id)")
    pools_age=$(pools_age_secs)
    [ -n "$pools_age" ] && [ "$pools_age" -gt "$pools_stale_secs" ] && pools_stale=true
    while IFS="$us" read -r p_who p_label p_kind p_rule p_pct p_iso p_at; do
        [ -z "$p_who" ] && continue
        if [ "$p_who" = me ]; then
            me_label="$p_label"; me_rule="$p_rule"; continue
        fi
        if [ "$p_kind" = codex ]; then
            [ -n "${MONCLAUDE_NO_CODEX:-}" ] && continue
            if [ -n "$codex_limits" ]; then
                p_age=$(secs_until "$p_at")
                if [ -n "$p_age" ] && [ $(( -p_age )) -le "$pools_stale_secs" ]; then
                    codex_limits=""
                else
                    continue
                fi
            fi
        fi
        others+="${p_label}${us}${p_rule}${us}${p_pct}${us}${p_iso}"$'\n'
    done <<< "$pools"
fi

# ── "Unused weekly quota" nudge ───────────────────────
# When the 7-day window resets within 2 days and you've used less than half
# of it, surface how much is still on the table — a heads-up to spend the
# headroom before it rolls over (handy if you work in bursts).
week_nudge=""
if [ -n "$usage" ]; then
    week_secs=$(secs_until "$week_reset_iso")
    if [ -n "$week_secs" ] && [ "$week_secs" -gt 0 ] \
        && [ "$week_secs" -le 172800 ] && [ "$week_pct" -lt 50 ]; then
        week_nudge=$(( 100 - week_pct ))
    fi
fi

# ── 5h → 7d contribution tracking ─────────────────────
# Snapshot seven_day.utilization at the first render of each 5h window,
# then show how much *this* window has added to the 7d total (delta in
# percentage points). Baseline rolls over automatically when the
# five_hour.resets_at timestamp changes.
baseline_file="$cache_dir/statusline-5h-baseline.json"
week_delta=""
if [ -n "$usage" ]; then
    week_pct_raw=$(echo "$usage" | jq -r '.seven_day.utilization // 0')
    current_5h_resets=$(echo "$usage" | jq -r '.five_hour.resets_at // empty')
    if [ -n "$current_5h_resets" ]; then
        baseline_resets=""
        baseline_week=""
        if [ -f "$baseline_file" ]; then
            baseline_resets=$(jq -r '.resets_at // empty' "$baseline_file" 2>/dev/null)
            baseline_week=$(jq -r '.week_pct // empty' "$baseline_file" 2>/dev/null)
        fi
        if [ "$baseline_resets" != "$current_5h_resets" ] || [ -z "$baseline_week" ]; then
            # New 5h window (or first run) — snapshot current as baseline.
            tmp_b="${baseline_file}.tmp.$$"
            if printf '{"resets_at":"%s","week_pct":%s}\n' "$current_5h_resets" "$week_pct_raw" > "$tmp_b" 2>/dev/null; then
                mv "$tmp_b" "$baseline_file" 2>/dev/null || rm -f "$tmp_b"
            fi
            baseline_week="$week_pct_raw"
        fi
        if [ -n "$baseline_week" ]; then
            # Clamp negative (7d window rolled independently of 5h — rare) to 0.
            # Render 1 decimal for sub-1pp; drop the row entirely below 0.1pp.
            week_delta=$(awk "BEGIN {
                d = $week_pct_raw - $baseline_week;
                if (d < 0.1) { exit 0 }
                if (d < 10) printf \"%.1f\", d;
                else printf \"%.0f\", d;
            }")
        fi
    fi
fi

# ══════════════════════════════════════════════════════
# ONE-LINE MODE (MONCLAUDE_LINES=1) — percentages only
# events | Op5.5 high | Claude 1 20% 2d5h · Fable 2% | Codex 35% 3d20h · Gemini 17% 5d9h
# Session, then this account, then the other accounts: percentage coloured
# by level (teal → gold → amber → red) and a short time until it resets.
# ══════════════════════════════════════════════════════

if [ "${MONCLAUDE_LINES:-}" = 1 ] && [ "$cols" -ge 80 ]; then
    sep=" ${dim}|${reset} "
    dot=" ${dim}·${reset} "
    pc() { printf '%b' "$(pct_color "$1")$1%${reset}"; }
    # Time until reset, short: 2d5h, 5h, 40m (nothing if unknown or past).
    rs() {
        local d; d=$(secs_until "$1")
        [ -z "$d" ] || [ "$d" -le 0 ] && return
        if [ "$d" -ge 86400 ]; then printf '%b' " ${dim}$(( d / 86400 ))d$(( d % 86400 / 3600 ))h${reset}"
        elif [ "$d" -ge 3600 ]; then printf '%b' " ${dim}$(( d / 3600 ))h${reset}"
        else printf '%b' " ${dim}$(( d / 60 ))m${reset}"; fi
    }
    line=""
    [ -n "$loc_folder" ] && [ "$cols" -ge 100 ] && line="${white}${loc_folder}${reset}${sep}"
    line+="${blue}$(short_model "$model")${reset}"
    [ -n "$effort_label" ] && line+=" ${effort_color}${effort_label}${reset}"
    # No context gauge or cost here: in this mode only the limits matter.

    acct=""
    if [ -n "$usage" ]; then
        acct="${white}${me_label:-7d}${reset}"
        [ -n "$me_rule" ] && acct+=" ${yellow}${me_rule}${reset}"
        acct+=" $(pc "$week_pct")$(rs "$week_reset_iso")"
        $five_known && acct+=" ${dim}5h${reset} $(pc "$five_pct")$(rs "$five_reset_iso")"
        if [ -n "$scoped_limits" ]; then
            while IFS=$'\t' read -r s_name s_pct s_iso _; do
                [ -z "$s_name" ] && continue
                acct+="${dot}${white}${s_name}${reset} $(pc "$s_pct")"
                # A per-model cap usually resets with the week; only show its time if it differs.
                s_d=$(secs_until "$s_iso"); w_d=$(secs_until "$week_reset_iso")
                if [ -n "$s_d" ] && { [ -z "$w_d" ] || [ $(( s_d - w_d )) -gt 3600 ] || [ $(( w_d - s_d )) -gt 3600 ]; }; then
                    acct+="$(rs "$s_iso")"
                fi
            done <<< "$scoped_limits"
        fi
        [ "$extra_enabled" = "true" ] && acct+=" ${cyan}+\$${extra_used}${reset}"
    elif $usage_error; then
        acct="${yellow}usage api down${reset}"
    fi
    [ -n "$acct" ] && line+="${sep}${acct}"

    rest=""
    if [ -n "$codex_limits" ]; then
        while IFS=$'\t' read -r c_name c_win c_pct c_iso; do
            [ -z "$c_name" ] && continue
            [ -n "$rest" ] && rest+="$dot"
            rest+="${white}${c_name}${reset} $(pc "$c_pct")$(rs "$c_iso")"
        done <<< "$codex_limits"
    fi
    if [ -n "$others" ]; then
        while IFS="$us" read -r o_label _ o_pct o_iso; do
            [ -z "$o_label" ] && continue
            [ -n "$rest" ] && rest+="$dot"
            if [ "$o_pct" = "?" ]; then rest+="${white}${o_label}${reset} ${dim}?${reset}"
            else rest+="${white}${o_label}${reset} $(pc "$o_pct")$(rs "$o_iso")"; fi
        done <<< "$others"
        $pools_stale && rest+=" ${yellow}(old)${reset}"
    fi
    [ -n "$rest" ] && line+="${sep}${rest}"

    printf "%b" "$line"
    exit 0
fi

# ══════════════════════════════════════════════════════
# COMPACT MODE (< 80 cols — phones, VPS, narrow panes)
# One line, no bars — color-coded percentages
# Op4.6 high 7% ~$2.25 · 5h 7% in 2h · 7d 9% in 4d
# ══════════════════════════════════════════════════════

if [ "$cols" -lt 80 ]; then
    smodel=$(short_model "$model")
    pct_c=$(pct_color $pct_used)
    five_c=$(pct_color "$five_pct")
    week_c=$(pct_color "$week_pct")

    line=""
    if [ -n "$me_label" ]; then
        line="${white}${me_label}${reset}"
        [ -n "$me_rule" ] && line+=" ${yellow}${me_rule}${reset}"
        line+=" ${dim}·${reset} "
    fi
    line+="${blue}${smodel}${reset}"
    [ -n "$effort_label" ] && line+=" ${effort_color}${effort_label}${reset}"
    line+=" ${pct_c}${pct_used}%${reset} ${dim}~${cost_fmt}${reset}"

    if [ -n "$usage" ]; then
        # Account has no 5h limit (e.g. verified Ultra): hide the gauge.
        if $five_known; then
            line+=" ${dim}·${reset} ${dim}5h ${reset}${five_c}${five_pct}%${reset}"
            [ -n "$five_reset" ] && line+=" ${dim}${five_reset}${reset}"
        fi
        line+=" ${dim}· 7d ${reset}${week_c}${week_pct}%${reset}"
        [ -n "$week_delta" ] && line+=" ${dim}+${week_delta}pp${reset}"
        [ -n "$week_reset" ] && line+=" ${dim}${week_reset}${reset}"
        [ -n "$week_nudge" ] && line+=" ${nudge}${week_nudge}% left${reset}"
        if [ -n "$scoped_limits" ]; then
            while IFS=$'\t' read -r s_name s_pct s_iso _; do
                [ -z "$s_name" ] && continue
                s_c=$(pct_color "$s_pct")
                line+=" ${dim}· ${s_name} ${reset}${s_c}${s_pct}%${reset}"
                s_reset=$(fmt_reset "$s_iso")
                [ -n "$s_reset" ] && line+=" ${dim}${s_reset}${reset}"
            done <<< "$scoped_limits"
        fi
        if [ "$extra_enabled" = "true" ]; then
            line+=" ${cyan}+\$${extra_used}${reset}"
        fi
    elif $usage_error; then
        line+=" ${dim}·${reset} ${yellow}usage api down${reset} ${dim}(upstream)${reset}"
    fi
    if [ -n "$codex_limits" ]; then
        while IFS=$'\t' read -r c_name c_win c_pct c_reset; do
            [ -z "$c_name" ] && continue
            c_c=$(pct_color "$c_pct")
            line+=" ${dim}· ${c_name} ${c_win} ${reset}${c_c}${c_pct}%${reset}"
            c_reset=$(fmt_reset "$c_reset")
            [ -n "$c_reset" ] && line+=" ${dim}${c_reset}${reset}"
        done <<< "$codex_limits"
    fi
    if [ -n "$others" ]; then
        while IFS="$us" read -r o_label _ o_pct _; do
            [ -z "$o_label" ] && continue
            if [ "$o_pct" = "?" ]; then
                line+=" ${dim}· ${o_label} ?${reset}"
            else
                line+=" ${dim}· ${o_label} ${reset}$(pct_color "$o_pct")${o_pct}%${reset}"
            fi
        done <<< "$others"
        $pools_stale && line+=" ${yellow}(old)${reset}"
    fi

    printf "%b" "$line"
    exit 0
fi

# ══════════════════════════════════════════════════════
# FULL MODE (>= 80 cols — desktop / wide terminal)
# ══════════════════════════════════════════════════════

# LINE 1: [folder branch |] Model [effort] | context bar | cost
# Location only when there is room for it (>= 100 cols).
line1=""
if [ -n "$loc_folder" ] && [ "$cols" -ge 100 ]; then
    line1="${white}${loc_folder}${reset}"
    [ -n "$loc_branch" ] && line1+=" ${dim}⎇ ${loc_branch}${reset}"
    line1+=" ${dim}|${reset} "
fi
line1+="${blue}${model}${reset}"
[ -n "$effort_label" ] && line1+=" ${effort_color}${effort_label}${reset}"
line1+=" $(build_bar $pct_used 12)"
line1+=" ${cyan}$(fmt_tok "$current")${dim}/${reset}${cyan}$(fmt_tok "$size")${reset}"
line1+=" ${dim}|${reset} ${dim}~${cost_fmt}${reset}"

# LINE 2: 5hr | weekly | extra  (or rate-limit indicator)
line2=""
if [ -n "$usage" ]; then
    # Account has no 5h limit (e.g. verified Ultra): hide the gauge.
    if $five_known; then
        line2="${white}5h${reset} $(build_bar "$five_pct" 12)"
        [ -n "$five_reset" ] && line2+=" ${dim}${five_reset}${reset}"
        line2+=" ${dim}|${reset} "
    fi
    line2+="${white}7d${reset} $(build_bar "$week_pct" 12)"
    [ -n "$week_delta" ] && line2+=" ${dim}+${week_delta}pp 5h${reset}"
    [ -n "$week_reset" ] && line2+=" ${dim}${week_reset}${reset}"
    [ -n "$week_nudge" ] && line2+=" ${nudge}· ${week_nudge}% left before reset${reset}"
    # Per-model caps as a coloured percentage (no bar): they share the weekly reset.
    if [ -n "$scoped_limits" ]; then
        while IFS=$'\t' read -r s_name s_pct _ _; do
            [ -z "$s_name" ] && continue
            line2+=" ${dim}·${reset} ${white}${s_name}${reset} $(pct_color "$s_pct")${s_pct}%${reset}"
        done <<< "$scoped_limits"
    fi
    if [ "$extra_enabled" = "true" ]; then
        line2+=" ${dim}|${reset} "
        line2+="${white}extra${reset} ${cyan}\$${extra_used}${dim}/\$${extra_limit}${reset}"
    fi
elif $usage_error; then
    line2="${dim}usage api down upstream (HTTP 429, anthropics/claude-code#30930) — auto-retry${reset}"
fi
if [ -n "$codex_limits" ]; then
    while IFS=$'\t' read -r c_name c_win c_pct c_reset; do
        [ -z "$c_name" ] && continue
        [ -n "$line2" ] && line2+=" ${dim}|${reset} "
        line2+="${white}${c_name} ${c_win}${reset} $(pct_color "$c_pct")${c_pct}%${reset}"
        c_reset=$(fmt_reset "$c_reset")
        [ -n "$c_reset" ] && line2+=" ${dim}${c_reset}${reset}"
    done <<< "$codex_limits"
fi

if [ -n "$me_label" ]; then
    acct="${white}${me_label}${reset}"
    [ -n "$me_rule" ] && acct+=" ${yellow}${me_rule}${reset}"
    if [ -n "$line2" ]; then line2="${acct} ${dim}|${reset} ${line2}"; else line2="$acct"; fi
fi

# Other accounts (pools file): appended to line 2 as coloured percentages,
# no bars or reset times, so the status line stays at two lines.
if [ -n "$others" ]; then
    others_txt=""
    while IFS="$us" read -r o_label _ o_pct _; do
        [ -z "$o_label" ] && continue
        [ -n "$others_txt" ] && others_txt+=" ${dim}·${reset} "
        if [ "$o_pct" = "?" ]; then
            others_txt+="${white}${o_label}${reset} ${dim}?${reset}"
        else
            others_txt+="${white}${o_label}${reset} $(pct_color "$o_pct")${o_pct}%${reset}"
        fi
    done <<< "$others"
    $pools_stale && others_txt+=" ${yellow}(old)${reset}"
    if [ -n "$line2" ]; then line2+=" ${dim}|${reset} ${others_txt}"; else line2="$others_txt"; fi
fi

printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"

exit 0
