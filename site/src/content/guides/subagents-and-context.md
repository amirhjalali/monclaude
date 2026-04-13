---
title: Sub-agents and the art of keeping context clean
description: How to use Explore, Plan, and custom sub-agents to do more work in less context — and when to stop delegating.
pubDate: 2026-04-13
tags: ["subagents", "context", "claude-code"]
order: 4
---

Context is the agent's working memory. Everything you read in and everything
it reads from the filesystem competes for space. Once you push past a few
hundred thousand tokens, quality falls off a cliff: the model starts
forgetting earlier decisions, repeating itself, or inventing facts.

Sub-agents are how you do serious work without drowning the main thread.

## The mental model

Your main conversation is a **synthesis thread**. It should hold: the goal,
the decisions you've made, and the code you've actually touched.

Sub-agents are **scratch threads**. They do the reading, searching, and
exploring that would otherwise pollute the synthesis thread with tool
results.

The key property: when a sub-agent returns, only its final answer enters your
context. The intermediate tool noise stays in the sub-agent.

## When to spawn

- **Search that might take multiple rounds.** "Find all the call sites of X
  and classify them." Use `Explore`.
- **Design discussions you want a second perspective on.** Use `Plan`.
- **Large file reads where you only need a summary.** Give the sub-agent a
  specific question, not "summarize this file."
- **Parallelizable work.** Three independent investigations at once beat
  three sequential ones, and none of them pollute the main thread.

## When not to spawn

- **Trivial lookups.** If a single `Grep` or `Read` will do it, just do it.
  Sub-agents have overhead.
- **Work that requires the synthesis thread's own memory.** "Continue the
  refactor we started" — the sub-agent doesn't know what you started.
- **Tasks where you already know the answer.** Don't ask sub-agents to
  rubber-stamp your instincts.

## Brief the sub-agent like a new colleague

A sub-agent hasn't seen your conversation. The single biggest failure mode is
a vague prompt that lands on an agent with zero context.

Bad:

```text
Look at the codebase and tell me what to do.
```

Good:

```text
Audit `src/commands/usage.ts`. Goal: we want to add a `--json` flag that
outputs machine-readable output. Answer: (1) is there an existing JSON
formatter we should reuse? Check `src/lib/formatters/`. (2) are any callers
already piping output through `jq`? Grep in examples/ and docs/. (3) what's
the existing flag-parsing pattern? Keep it under 200 words.
```

The good prompt encodes everything the sub-agent needs: the goal, where to
look, and how to report back. The word-count ceiling keeps its answer
small enough to paste back into your context without breaking the bank.

## Custom agents for recurring work

If you review every PR with the same checklist, put it in a custom agent
definition. If you always want a security-focused reviewer, define
`security-reviewer`. Custom agents are prompt + tool config you don't have to
retype.

## The exit criterion

You've used sub-agents well when:

- Your main thread is mostly your decisions and the actual diff.
- Your sub-agents' summaries read like memos, not transcripts.
- You can come back after lunch and pick up where you left off without
  scrolling for five minutes.

If your main thread is full of `Read` tool outputs, you're doing too much
work in it.
