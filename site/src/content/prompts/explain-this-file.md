---
title: Explain this file (for real)
description: A prompt that produces a useful summary of an unfamiliar file — structure, contracts, gotchas — not a tutorial.
pubDate: 2026-04-13
tags: ["onboarding", "reading"]
agent: "any"
---

Most "explain this code" prompts produce a tutorial aimed at a beginner. When
you're onboarding to a real codebase, you don't need a tutorial. You need a
memo.

## The prompt

```text
Read the file and write a memo for a senior engineer new to the codebase.

Sections, in order, using exactly these headings:

## One-liner
<what this file is, in 15 words or fewer>

## Public surface
<exported names and one-line purpose>

## Internal structure
<the 3–6 most important internal functions/types and how they relate>

## Contracts
<invariants, assumptions, ordering requirements, thread-safety, etc.>

## Gotchas
<things a contributor would likely get wrong>

## What it does NOT do
<common misconceptions about scope>

Rules:
  - No tutorials. The reader has 10+ years of experience.
  - Cite specific lines (file:line) when you reference code.
  - Skip obvious things. If it's just a wrapper around stdlib, say so and stop.
  - Under 400 words total.

File:
---
<paste file here, or reference by path>
```

## Why it works

The "memo for a senior engineer" framing is doing most of the work. It kills
the instinct to explain language features and forces the agent into a
posture of *summarizing* rather than *teaching*.

The word ceiling is the second-most important part. Without it, you get a
wall of text. With it, the agent picks the important bits.
