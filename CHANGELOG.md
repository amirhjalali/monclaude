# Changelog

All notable changes to `monclaude` will be documented here.

## Unreleased

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
