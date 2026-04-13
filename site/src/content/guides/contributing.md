---
title: The content pipeline behind this site
description: How Clawed-Code content gets from a markdown file to a published page — and how to add your own.
pubDate: 2026-04-13
tags: ["meta", "contributing", "pipeline"]
order: 90
---

Everything on this site is a markdown file in `site/src/content/`. There is
no CMS, no database, no drafts-in-cloud. If you can edit a `.md` file and
open a PR, you can contribute.

## Anatomy of a post

```
site/src/content/
├── guides/             ← walkthroughs & playbooks
│   └── getting-started.md
├── tools/              ← tools I use, featured or not
│   └── monclaude.md
└── prompts/            ← copy-paste prompts
    └── code-review.md
```

Each collection has a schema in
[`src/content.config.ts`](https://github.com/amirhjalali/clawed-code/blob/main/site/src/content.config.ts).
The build fails loudly if your frontmatter is wrong — that's a feature, not a
bug.

### Guide frontmatter

```yaml
---
title: "A short, opinionated title"
description: "One or two sentences. This shows on cards and in social previews."
pubDate: 2026-04-13
tags: ["prompting", "claude-code"]
order: 10           # lower = earlier in the list
draft: false        # set true to hide from the site
---
```

### Tool frontmatter

```yaml
---
title: "monclaude"
description: "A rich status line for Claude Code."
pubDate: 2026-01-01
repo: "https://github.com/amirhjalali/monclaude"
tags: ["claude-code", "cli"]
featured: true
---
```

### Prompt frontmatter

```yaml
---
title: "Diff-first code review"
description: "Hand Claude your diff and ask for a focused review."
pubDate: 2026-04-13
tags: ["review", "prompt"]
agent: "claude-code"     # or claude-api | cursor | other | any
---
```

## The scaffolding script

Instead of copying an existing file, use the scaffolder:

```bash
pnpm new guide "Designing a CLAUDE.md"
pnpm new tool "ripgrep"
pnpm new prompt "Diff-first code review"
```

It slugifies the title, sets today's date, stubs the frontmatter, and opens
the file in `$EDITOR` if it's set.

## Local preview

```bash
cd site
pnpm install
pnpm dev         # http://localhost:4321
```

Hot reload picks up content changes within a second.

## Deployment

Merges to `main` trigger a GitHub Actions workflow that builds the site and
publishes to the production host (currently Cloudflare Pages). PRs get
preview deployments automatically.

## Editorial rules

- **Be specific.** Vague advice helps nobody. Paste real prompts, show real
  diffs, name real tools.
- **Be honest.** If a pattern has downsides, name them. If you haven't
  actually used the tool, don't write about it.
- **Be short.** The bar is "would I read this if it weren't mine?"
- **Cite sources.** If a pattern has a name in the wild, use it. Link the
  docs where appropriate.

## Licensing

Content is MIT-licensed along with the code. By opening a PR you agree to
publish under the same license. Co-authored commits are welcome and
encouraged.
