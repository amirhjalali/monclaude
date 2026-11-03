# Changelog

All notable changes to `monclaude` will be documented here.

## 0.2.0 — 2026-11-03

- Fixed usage numbers freezing when `/api/oauth/usage` returns
  `five_hour: null`. Responses were judged valid by a non-null `five_hour`,
  so every such 200 was taken for an error (and shown as `usage api down`),
  leaving the cache on its last older response: per-model caps, extra
  credits and, without live data, 7d stopped updating. Any payload with a
  `five_hour` or `seven_day` key now counts.
- The 5h gauge is hidden for accounts with no 5-hour limit (e.g. verified
  Ultra), detected as `five_hour: null` with no `session` entry in the
  `limits` array. Capped accounts keep it, between windows too. `monclaude
  usage --json` reports `five_hour: null` for these accounts.
- Codex gauge picks the newest rollouts by mtime, not by name, so a
  long-running or resumed Codex session no longer goes stale.
- 5-hour and 7-day gauges now come from the live `rate_limits` Claude Code
  puts in the status JSON (read from the rate-limit headers of every reply)
  instead of polling `/api/oauth/usage`. They stay current and no longer
  vanish into `usage api down` during the endpoint's 429 loops. The API is
  now only needed for per-model caps and extra credits, and is polled every
  10 minutes while live data flows. `monclaude usage` uses the last live
  snapshot (`statusline-live-limits.json`) when it is under 10 minutes old.
- Added Codex (OpenAI) rate limits next to Claude's: a `Codex 7d` gauge on
  line 2 (and in compact mode), a line in `monclaude usage`, and a `codex`
  array in `monclaude usage --json`. Read from the newest `rate_limits`
  snapshot in `~/.codex/sessions` (honours `CODEX_HOME`), cached for 60s,
  and reset to 0% once a window's reset time passes. Extra Codex limits
  (e.g. Spark) show only when used. `MONCLAUDE_NO_CODEX=1` turns it off.
- Fixed the effort indicator drifting from the session: it now reads the live
  `effort.level` Claude Code sends in the status JSON (follows `/effort` and
  model switches) instead of the saved `effortLevel` default in
  `~/.claude/settings.json`, which is only used as a fallback on older
  Claude Code versions.
- Added the session's folder and git branch to the start of line 1 in full
  mode (100+ columns), e.g. `monclaude ⎇ main | Opus 4.8 …`. Long branch
  names are clipped; `MONCLAUDE_NO_LOCATION=1` turns it off.
- Added per-model scoped weekly limits (e.g. the separate Fable cap) parsed
  from the usage API's `limits` array: rendered as an extra gauge on line 2
  (full mode), appended in compact mode and `monclaude usage`, and exposed as
  the `weekly_scoped` array (with `severity` and `is_active`) in
  `monclaude usage --json`.
- Added `monclaude usage` and `monclaude usage --json` commands for agents and autonomous loops: machine-readable 5-hour and 7-day utilisation, headroom, reset timers, extra-credit spend, staleness flag, and error flag with exit codes.
- Added `MONCLAUDE_CACHE_DIR` environment variable to override the cache directory (used by tests and agents that need isolation).
- Refactored cache hydration into a shared `ensure_usage_cache` function used by both the status line and the `usage` subcommand.
- Added Homebrew formula and install documentation.
- Added launch-post draft.
- Documented compact mode, effort indicators, weekly burn tracking, and usage API backoff.
- Added verification and troubleshooting notes for first-time users.

## 0.1.0

- Initial public release.
- Added Claude Code status line script, installer, screenshot, MIT license, and ShellCheck CI.
