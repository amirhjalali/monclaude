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
Opus 4.8 (1M context)  xhigh  [▓▓ 22% ]  220k/1.0m  |  ~$1.24
5h [▓▓▓ 34% ] in 2h 6m  |  7d [▓▓ 31% ] in 1d 4h · 69% left before reset
```

Each gauge is a compact bar with the percentage riding inside it, so the
number costs no extra width. Bars stay cool (teal) while you have headroom
and warm up (gold → amber → red) as you approach a limit.

**Line 1** — Session vitals
- Model name and context size
- Reasoning effort level — `low` / `med` / `high` / `xhigh` / `max`, color-coded (shown when set in Claude settings)
- Context window usage bar with the percentage inside it
- Tokens used vs total
- Running session cost

**Line 2** — Rate limits & billing
- 5-hour rolling usage with time until reset
- 7-day rolling usage with time until reset
- 5-hour contribution to the 7-day window
- "Use it" nudge when the weekly window resets soon and you still have a lot
  unused (e.g. `· 69% left before reset`)
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

The bars stay cool while you have room and warm up as usage climbs, so a
glance tells you whether you're fine or close to a limit:

| Usage | Color |
|-------|-------|
| 0–49% | Teal |
| 50–69% | Gold |
| 70–89% | Amber |
| 90–100% | Red |

The effort indicator uses its own cool→warm ramp next to the model name — it
tracks depth of thinking, not how close you are to a limit, so every level
gets a distinct hue:

| Effort | Label | Color |
|--------|-------|-------|
| low | `low` | Teal |
| medium | `med` | Soft green |
| high | `high` | Gold |
| xhigh | `xhigh` | Amber |
| max | `max` | Red |

## License

[MIT](LICENSE)
