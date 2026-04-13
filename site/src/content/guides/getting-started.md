---
title: Getting started with Claude Code
description: A 10-minute orientation for developers sitting down with Claude Code for the first time. Install, configure, and form the habits that matter.
pubDate: 2026-04-13
tags: ["claude-code", "setup", "basics"]
order: 1
---

Claude Code is a terminal-first coding agent. This guide gets you from zero to
shipping your first useful diff in about ten minutes.

## 1. Install

```bash
# macOS / Linux
curl -fsSL https://claude.ai/install.sh | bash

# then authenticate
claude login
```

Subscribe to Claude Pro, Max, or Team — pay-as-you-go API keys work too, but
Max is a better deal if you're coding every day.

## 2. Make your first `CLAUDE.md`

Drop a `CLAUDE.md` file in the root of your repo. This is the single most
impactful thing you can do. Claude reads it at the start of every session.
Keep it short and opinionated:

```md
# Project: monclaude

- Status line script for Claude Code, pure bash, zero deps besides `jq`.
- Supports macOS and Linux. Tested with bash 3.2+.
- Style: small functions, early returns, no sub-shells when a builtin works.

## Commands

- `shellcheck monclaude.sh` — lint before you commit.
- `bash monclaude.sh < tests/fixtures/session.json` — smoke test.

## Gotchas

- Don't use `date -d` (GNU-only); branch on `$is_mac` first.
- 60s cache at `/tmp/claude/statusline-usage-cache.json` — blow it away when debugging.
```

A good `CLAUDE.md` is closer to a concise README than a prompt. Describe the
project, list commands it should run, warn it off the common pitfalls.

## 3. Use plan mode before any non-trivial change

Shift-Tab twice (or `/plan`) to enter plan mode. Claude reads code and proposes
a change without editing anything. Review the plan. If it's wrong, it's wrong
cheaply.

The rule of thumb: any task you couldn't describe in a single sentence
benefits from plan mode.

## 4. Use sub-agents to keep your context clean

Large searches and multi-file exploration fill the main context with noise.
Delegate them:

- `Explore` agent — for "find me everything that touches X"
- `Plan` agent — for "how should we approach this"
- Custom agents — for anything recurring (code review, test-writing)

Your main conversation stays about the actual work.

## 5. Know your status

Context windows, usage caps, and peak-hours pricing will bite you.
[monclaude](/tools/monclaude/) puts it all in your status line so you stop
guessing.

## 6. Commit often, let Claude write the message

```text
/commit
```

The built-in commit skill reads your diff, infers the "why," and writes a
one-liner that doesn't suck. Beats `git commit -m "updates"`.

## What to read next

- [Prompting for code](/guides/prompting-for-code/)
- [Designing a CLAUDE.md](/guides/designing-a-claude-md/)
- [The content pipeline behind this site](/guides/contributing/)
