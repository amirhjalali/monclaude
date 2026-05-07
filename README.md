# monclaude

[![shellcheck](https://github.com/amirhjalali/monclaude/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/amirhjalali/monclaude/actions/workflows/shellcheck.yml)
[![release](https://img.shields.io/github/v/release/amirhjalali/monclaude?color=333333)](https://github.com/amirhjalali/monclaude/releases)
[![license](https://img.shields.io/github/license/amirhjalali/monclaude?color=333333)](LICENSE)

A real-time status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). See context usage, rate limits, reset timers, weekly burn, and cost without leaving your terminal.

> *mon claude* — "my Claude" in French. Also: **mon**itor **Claude**.

![screenshot](screenshot.png)

## Why Use It

Claude Code already gives you the work. `monclaude` gives you the instrument panel: how much context is left, how fast your 5-hour window is burning, when limits reset, and whether the current session is getting expensive.

It is a single shell script, so agents can install it, inspect it, and modify it without a package manager.

## What You Get

```
Opus 4.6 (1M context) | ●●○○○○○○○○ 150k/1.0m (15%) | ~$1.24
5hr ●○○○○○○○○○ 10% in 2h 6m | 7d ●○○○○○○○○○ 11% +1.2pp 5h in 4d 11h | extra $33.05/$50
```

**Line 1** — Session vitals
- Model name and context size
- Effort level indicator when present in Claude settings
- Context window usage bar (color-coded green → orange → yellow → red)
- Tokens used vs total with percentage
- Running session cost

**Line 2** — Rate limits & billing
- 5-hour rolling usage with time until reset
- 7-day rolling usage with time until reset
- 5-hour contribution to the 7-day window
- Extra credits used / monthly cap (if enabled)
- Clear upstream error indicator when the usage API is temporarily stuck

## Install

**Homebrew:**

```bash
brew tap amirhjalali/monclaude https://github.com/amirhjalali/monclaude
brew install monclaude
```

Configure Claude Code to call the Homebrew-installed script:

```json
{
  "statusLine": {
    "type": "command",
    "command": "monclaude"
  }
}
```

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/amirhjalali/monclaude/main/install.sh | bash
```

Then restart Claude Code.

**Ask Claude Code to do it:**

Paste this prompt into Claude Code and it will install monclaude for you:

> Download https://raw.githubusercontent.com/amirhjalali/monclaude/main/monclaude.sh to ~/.claude/monclaude.sh, make it executable, ensure jq is installed, and in ~/.claude/settings.json set the statusLine field to {"type": "command", "command": "~/.claude/monclaude.sh"}

**Manual:**

```bash
# Download
curl -fsSL https://raw.githubusercontent.com/amirhjalali/monclaude/main/monclaude.sh -o ~/.claude/monclaude.sh
chmod +x ~/.claude/monclaude.sh

# Configure Claude Code
# Add to ~/.claude/settings.json:
# { "statusLine": { "type": "command", "command": "/path/to/monclaude.sh" } }
```

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [`jq`](https://jqlang.github.io/jq/) — `brew install jq`
- macOS or Linux
- A Claude Pro, Max, or Team subscription (for usage data)

## How it works

1. Claude Code pipes session JSON (model, context, cost) into the status line script via stdin
2. The script calls the Anthropic usage API to fetch 5-hour and 7-day rate limit data
3. API responses are cached for 180 seconds at `/tmp/claude/statusline-usage-cache.json` (stretched to 30 min when the upstream endpoint is stuck in its known 429 loop — see anthropics/claude-code#30930) and a `mkdir` mutex serializes refreshes across concurrent sessions
4. Narrow terminals automatically switch to compact one-line mode

## Verify

Run ShellCheck locally:

```bash
shellcheck monclaude.sh install.sh
```

Or let GitHub Actions run the included ShellCheck workflow on every push and pull request.

## Troubleshooting

**Shows only `Claude`**  
Claude Code did not pass status JSON yet, or the command is not configured in `~/.claude/settings.json`.

**Shows `usage api down`**  
The upstream usage endpoint is returning invalid data or rate limiting. `monclaude` preserves the last valid cache and backs off automatically.

**Usage data missing on Linux**  
Make sure `~/.claude/.credentials.json` exists and contains Claude Code OAuth credentials.

## Color coding

The progress bars shift color as usage climbs:

| Usage | Color |
|-------|-------|
| 0–49% | Green |
| 50–69% | Orange |
| 70–89% | Yellow |
| 90–100% | Red |

## License

[MIT](LICENSE)
