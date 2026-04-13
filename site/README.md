# clawed-code

Source for [clawed-code.com](https://clawed-code.com) — field notes on
working with Claude and other coding agents.

## Stack

- [Astro 5](https://astro.build) with content collections
- [Tailwind 4](https://tailwindcss.com) via `@tailwindcss/vite`
- MDX, RSS, sitemap
- Deploys to Cloudflare Pages (see `.github/workflows/deploy.yml`)

## Run locally

```bash
pnpm install   # or npm install
pnpm dev       # http://localhost:4321
pnpm build     # static output → site/dist
pnpm preview   # serve the production build
```

## Add content

```bash
pnpm new guide "Designing a CLAUDE.md"
pnpm new tool "ripgrep"
pnpm new prompt "Diff-first code review"
```

Each command creates a markdown file in the right collection with stubbed
frontmatter, sets today's date, and opens it in `$EDITOR`.

Content lives in:

- `src/content/guides/` — walkthroughs and playbooks
- `src/content/tools/` — tools I actually use
- `src/content/prompts/` — copy-paste prompts

Schemas are defined in `src/content.config.ts`. The build fails loudly on
invalid frontmatter, which is the point.

Flip `draft: false` when a piece is ready to publish.

## Editorial bar

See [`/about`](https://clawed-code.com/about/) on the site. Short version:
be specific, be honest, be short.

## License

MIT. Open a PR and you agree to publish under the same.
