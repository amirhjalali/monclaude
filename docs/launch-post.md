# monclaude: A Real-Time Status Line for Claude Code

Claude Code is most useful when you can stay inside the terminal. The problem is that the important limits are invisible while you work: context window, 5-hour usage, 7-day usage, reset timers, and session cost.

`monclaude` adds that instrument panel directly to your Claude Code status line.

It shows:

- Current model and context window usage
- Session cost
- 5-hour and 7-day usage percentages
- Reset countdowns
- Extra-credit burn when enabled
- A compact one-line mode for narrow panes
- A clear upstream warning when Anthropic's usage endpoint is temporarily stuck

Install:

```bash
brew tap amirhjalali/monclaude https://github.com/amirhjalali/monclaude
brew install monclaude
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/amirhjalali/monclaude/main/install.sh | bash
```

Repo: https://github.com/amirhjalali/monclaude
