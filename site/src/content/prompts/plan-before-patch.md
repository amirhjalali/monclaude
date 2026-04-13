---
title: Plan before patch
description: Force a written plan before any non-trivial change. Two minutes of planning saves an hour of undo.
pubDate: 2026-04-13
tags: ["planning", "quality", "process"]
agent: "any"
---

Most of the time agents make a mess, it's because they started editing before
they finished reading. This prompt pre-commits them to reading first.

## The prompt

```text
Before you change anything, produce a plan in this exact shape:

## Goal
<one sentence>

## Files you will touch
<bulleted list with one-line reason per file>

## Files you will read but not touch
<bulleted list>

## Approach
<5–12 bullets, in order>

## Risks
<bullets. For each risk, the mitigation.>

## Verification
<the exact command(s) that will tell us it worked>

Do not edit any files yet. Output the plan only.
When I reply "go", proceed. If I ask questions, answer them and wait.
```

## How I use it

I save this as a Claude Code skill called `/plan-before`. Invoke it on any
task I'd estimate at >15 minutes of agent work. The time cost is a minute or
two. The upside is catching a wrong premise *before* the agent has rewritten
seven files.

## When to skip it

- Typo fixes.
- Dependency bumps with no breaking changes.
- Anything where you've already seen the diff in your head.

For everything else, plan-before-patch is the highest-leverage habit I know.
