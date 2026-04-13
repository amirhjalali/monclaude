---
title: Diff-first code review
description: Hand Claude your diff and ask for a focused review — no repo spelunking, no distraction.
pubDate: 2026-04-13
tags: ["review", "pr", "quality"]
agent: "claude-code"
---

The shorter the input, the sharper the review. Feeding Claude a raw diff keeps
it from wandering into unrelated files and second-guessing existing code.

## The prompt

```text
Review the diff below as if you were about to merge it.

Focus on, in order:
  1. Correctness — logic errors, off-by-ones, wrong API shapes, dead branches.
  2. Reversibility — is this easy to revert? Any migrations or external state?
  3. Blast radius — who else consumes the changed functions? Check callers.
  4. Tests — does the diff include tests for the changed behavior? If not,
     what would a minimal test look like?

Rules:
  - Cite specific lines (file:line).
  - If a concern depends on code not shown, say so — don't guess.
  - Skip style nits. Biome handles those.
  - End with one of: APPROVE / REQUEST_CHANGES / BLOCK, and a one-line why.

Diff:
---
<paste diff here>
```

## How I use it

```bash
git diff main...HEAD | claude -p "$(cat ~/.prompts/diff-first-review.md)"
```

Or, inside Claude Code:

```text
/review
```

…if you've saved the prompt as a skill.

## Why it works

- **Narrow input.** No chance of the agent commenting on unrelated files.
- **Ordered priorities.** Correctness before style is the right default.
- **Forced verdict.** `APPROVE / REQUEST_CHANGES / BLOCK` keeps the review
  actionable instead of a "hmm, interesting" monologue.
- **Admits uncertainty.** The "don't guess" rule catches the failure mode
  where the agent invents callers that don't exist.

## Variations

- Add `"Assume reviewer is a staff engineer."` for deeper critique.
- Add `"This is a hotfix — bias toward smallest safe change."` for incidents.
- Swap step 3 for `"Security — SQLi, XSS, auth bypass, secret leaks."` for
  security-sensitive PRs.
