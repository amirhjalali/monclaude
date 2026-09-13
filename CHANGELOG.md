# Changelog

All notable changes to `monclaude` will be documented here.

## Unreleased

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
