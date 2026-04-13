---
title: monclaude
description: A rich status line for Claude Code — context window, 5h/7d usage, peak hours, session cost. One script, zero deps besides jq.
pubDate: 2026-01-05
updatedDate: 2026-04-13
repo: "https://github.com/amirhjalali/monclaude"
tags: ["claude-code", "status-line", "cli", "bash"]
featured: true
---

`monclaude` is the status line I reach for in every Claude Code session. It
answers the three questions I was otherwise answering by hand every few
minutes:

1. How much of my context window have I used?
2. Where am I in my 5-hour and 7-day usage caps?
3. Is this PEAK time (weekdays 5–11am PT), when my allowance burns faster?

## What it looks like

```text
Opus 4.6 (1M context) | ●●○○○○○○○○ 150k/1.0m (15%) | ~$1.24
5hr ●○○○○○○○○○ 10% in 2h 6m PEAK | 7d ●○○○○○○○○○ 11% in 4d 11h | extra $33.05/$50
```

In compact mode (narrow terminals, phones) it collapses to a single line
without bars but keeps the color coding.

## Why I built it

The defaults don't tell you what you actually need. The model name isn't as
useful as the model name plus how close you are to running out of window.
Cost isn't as useful as cost plus your 5h reset time. The Claude Code session
JSON has everything — it just needs formatting.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/amirhjalali/monclaude/main/install.sh | bash
```

Or read `install.sh` first (always a good idea). Works on macOS and Linux.

## How it works

1. Claude Code pipes session JSON into the script via stdin.
2. The script calls the Anthropic usage API for 5h and 7d rate data.
3. Responses are cached for 60 seconds at
   `/tmp/claude/statusline-usage-cache.json` to stay snappy.
4. Peak hours are detected locally (weekdays 5–11am PT).

No Node, no Python, no daemon. Pure bash plus `jq`. If something breaks,
you can read the whole thing in one sitting.

## Color coding

Progress bars shift color as usage climbs, so you can see trouble at a glance:

| Usage | Color |
| --- | --- |
| 0–49% | green |
| 50–69% | orange |
| 70–89% | yellow |
| 90–100% | red |

## Why it's featured here

It's the tool I use most often and the first thing I install on a fresh
machine. More importantly, it's the canonical small tool: does one thing,
doesn't phone home, readable in one pass.
