---
title: Prompting for code
description: The differences between prompting for prose and prompting for code — and the handful of patterns that consistently produce better diffs.
pubDate: 2026-04-13
tags: ["prompting", "claude-code", "patterns"]
order: 2
---

Most "prompt engineering" advice was written for chatbots. Coding agents are a
different animal. They read your files, run your commands, and commit. The
prompts that work are less "be a senior engineer" and more "here are the
inputs; here is the definition of done."

## The five-part coding prompt

A reliable coding prompt has five parts:

1. **Goal.** What does "done" look like? State the observable outcome, not the
   implementation.
2. **Context.** Which files, which constraints, what's already been ruled out.
3. **Non-goals.** What should explicitly *not* change.
4. **Verification.** How will the agent know it worked? Tests to run, commands
   to execute, a UI screen to hit.
5. **Escape hatch.** What to do if stuck. "Ask me" beats "make something up."

A worked example:

```text
Goal: Make the `/usage` command show both 5h and 7d reset times.

Context: Logic lives in `src/commands/usage.ts`. Reset times are already on
the API response (see `five_hour.resets_at`, `seven_day.resets_at`). The
date formatter in `src/lib/time.ts#relative` handles ISO strings.

Non-goals: Do not change the API contract. Do not touch the status-line
formatting (owned by monclaude).

Verify: `pnpm test src/commands/usage.test.ts` and run `claude /usage` —
both rows should end with "in 2h 3m" style strings.

If the API response is missing a field, stop and ask. Don't fabricate.
```

This is not long. It is specific.

## Patterns worth stealing

### "Find, then fix"

Split investigation from implementation. Two prompts beat one sprawling one:

1. "Find every caller of `fooBar` and report a table of file, function, and
   current behavior." (Use an Explore sub-agent.)
2. "Here's the table. Change them all to call `fooBaz` instead, preserving
   behavior."

### "Proof of understanding"

Before making a non-trivial change, ask the agent to summarize the current
behavior in its own words. If the summary is wrong, the diff will be too —
and you'll catch it cheaply.

### "Diff-first review"

For reviews, feed the agent the diff, not the repo:

```text
git diff main...HEAD | claude -p "Review for bugs and reversibility. Short."
```

The narrower the input, the sharper the review.

### "Name the abstraction"

When the agent is about to invent a helper, stop and name it yourself. You'll
get better naming, clearer boundaries, and easier code review.

## Anti-patterns

- **"Make it better."** Better by what metric? Smaller? Faster? More typed?
  Pick one.
- **"Follow best practices."** Whose? Best practices are a project-local
  thing. Put them in `CLAUDE.md` and reference *those*.
- **"Fix the bug."** Fix which bug? Paste the error, the stack, and your
  hypothesis. Let the agent confirm or correct the hypothesis.
- **"Add tests."** Always specify the behavior the tests should pin down.
  Otherwise you get tautologies.

## The one-minute rule

If writing the prompt would take longer than one minute, you probably need to
break the task down. Coding agents are best at small, verifiable changes
stacked on top of each other.
