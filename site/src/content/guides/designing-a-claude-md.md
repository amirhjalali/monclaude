---
title: Designing a CLAUDE.md that earns its tokens
description: Your CLAUDE.md is a memo to every future session. Make it short, opinionated, and boring.
pubDate: 2026-04-13
tags: ["claude-code", "claude-md", "context"]
order: 3
---

Every session starts with Claude reading your `CLAUDE.md`. Those tokens cost
you — on context, on cost, and on the agent's attention. Budget accordingly.

## What to include

- **What this project is.** One or two sentences. "Status-line script for
  Claude Code, pure bash, macOS + Linux."
- **Commands.** The small set of things the agent will actually run:
  tests, linters, build, start-dev. Exact invocations.
- **Conventions.** Style choices that are non-obvious from reading the code.
  "Prefer early returns. No classes. Don't introduce dependencies."
- **Gotchas.** Subtle traps a new contributor would hit. "Don't use `date
  -d`, it's GNU-only. Branch on `$is_mac` first."
- **Pointers.** Where to look for X. "Routing lives in `src/router/*`. Types
  come from the generated `openapi.ts` — don't hand-edit."

## What to leave out

- **Prompting advice.** "Please write clean code." Claude already writes
  clean code.
- **Ego.** No "you are a senior engineer" framing.
- **Dependency lists.** `package.json` already has those.
- **Exhaustive architecture docs.** Link them; don't inline them.
- **Anything that changes weekly.** It'll rot.

## Structure

A three-section shape works well for most repos:

```md
# Project: <name>

<one-paragraph description>

## Commands

- `pnpm test` — unit tests
- `pnpm lint` — biome + typecheck
- `pnpm dev` — start the dev server on :3000

## Gotchas

- <thing that bit you>
- <thing that will bite future-you>
- <edge case that isn't obvious>
```

That's often the whole file. Resist the urge to grow it.

## Scoped CLAUDE.md files

Claude Code reads `CLAUDE.md` at the repo root, and also nested ones as it
descends. Use this. A `CLAUDE.md` in `packages/api/` can say "this package
uses Hono and Zod; errors throw `HttpError`; see `/packages/api/src/types/`"
without polluting the top-level file.

## Revise it when you find yourself repeating corrections

If you catch yourself saying "no, use `pnpm`, not `npm`" three times in a
week, that's a `CLAUDE.md` edit. Every repeated correction is a missing line
in your memo.

## A worked example

```md
# Project: clawed-code

Astro static site for publishing field notes on working with coding agents.

## Commands

- `pnpm dev` — local dev at http://localhost:4321
- `pnpm build` — static build into `dist/`
- `pnpm new <kind> <slug>` — scaffold a new guide, tool, or prompt

## Conventions

- Content lives in `src/content/{guides,tools,prompts}/*.md`. Never build
  pages by hand for content — use the collections.
- Frontmatter schema is defined in `src/content.config.ts`. If the build
  fails on schema, fix the frontmatter — don't loosen the schema.
- Styling is Tailwind 4 via `@tailwindcss/vite`. No CSS modules.

## Gotchas

- `pubDate` must be `YYYY-MM-DD` — the schema coerces but bad strings fail
  silently in `sort()`.
- Drafts (`draft: true`) are excluded everywhere via the filter helpers.
- Don't add `astro:content` imports in `.ts` files outside `src/` — the
  loader isn't wired up there.
```

Every line earns its place.
