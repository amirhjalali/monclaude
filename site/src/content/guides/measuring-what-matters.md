---
title: Measuring what matters with coding agents
description: Cost, tokens, latency, diff size. The four numbers worth watching and how to instrument them.
pubDate: 2026-04-13
tags: ["measurement", "cost", "productivity"]
order: 5
---

"Does the agent make me faster" is an almost-useless question. "How many
tokens did I spend to land the last ten commits, and what was the diff size
and revert rate" is a question you can actually answer.

## The four numbers

### 1. Cost per accepted change

Sum of token cost divided by number of commits you kept. Track it weekly. If
it's going up, you're either spinning or the tasks got harder.

### 2. Diff size per task

Agents love to touch more than they need to. Small, focused diffs are safer
and easier to review. If your median diff is growing, tighten your prompts.

### 3. Revert / amend rate

How often do you undo the agent's work within 24 hours? A high rate is a
signal — usually the prompts are under-specified or the tests aren't pinning
down the right behavior.

### 4. Time in plan vs. time in edit

Rough ratio. Too much plan time means you're deliberating instead of trying.
Too much edit time means you're brute-forcing without thinking.

## How to measure

### Cost and tokens

[monclaude](/tools/monclaude/) surfaces session cost and 5h/7d usage in the
status line. For longer-range tracking, the Anthropic usage API exposes
per-day breakdowns — pipe them into a spreadsheet weekly.

### Diff size and revert rate

```bash
# Lines touched per commit, last 30 days
git log --since="30 days ago" --pretty=tformat: --numstat \
  | awk '{adds += $1; dels += $2; n++} END {print "commits:", n, "avg lines:", (adds+dels)/n}'

# Commits that got reverted
git log --since="30 days ago" --oneline | grep -iE "revert|amend" | wc -l
```

### Time in plan vs. edit

The crudest form works: eyeball it at the end of each day. Tools like
[Wakatime](https://wakatime.com) can automate it, but for most people a
weekly retro is enough.

## What to do with the numbers

Numbers are only useful if they change your behavior. Some observed reflexes:

- **Cost spike + no diff-size change.** You're probably looping. Back up,
  restate the goal, try a different approach.
- **Diff-size growth + no cost change.** Agent is getting braver in the same
  token budget. Usually fine, but watch for accidental refactors.
- **Revert-rate growth.** Tests are weak or prompts are vague. Add a
  verification step to the prompt template.

## The honest caveat

These numbers are directional, not absolute. Don't optimize them to the
detriment of doing real work. The worst thing you can do with a productivity
metric is treat it like a golf score.
