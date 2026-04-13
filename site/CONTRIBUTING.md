# Contributing to Clawed-Code

Clawed-Code is a living collection of field notes on coding with Claude and
other agents. The content pipeline is just markdown files, a schema, and
Astro's static build. Contributing is meant to be low-friction.

## Shape of a contribution

There are three content types:

| Type    | What it is                                   | Path                        |
| ------- | -------------------------------------------- | --------------------------- |
| Guide   | A walkthrough, playbook, or opinion piece.   | `site/src/content/guides/`  |
| Tool    | A tool you use every day (yours or someone's). | `site/src/content/tools/` |
| Prompt  | A short, reusable prompt that earns its keep. | `site/src/content/prompts/`|

## Workflow

1. Fork `amirhjalali/clawed-code` and create a branch: `content/<slug>`.
2. Scaffold your file:
   ```bash
   cd site
   pnpm install
   pnpm new guide "Your title here"
   ```
3. Fill in the markdown. Keep `draft: true` while you iterate.
4. Preview locally: `pnpm dev`, open http://localhost:4321.
5. Flip `draft: false` when you're ready.
6. Open a PR. Preview deployments are automatic — the PR comment will link
   to a live build.

## Editorial bar

The three rules that keep this site useful:

- **Be specific.** No "use AI to be more productive" posts. Paste the actual
  prompt, name the actual tool, show the actual diff.
- **Be honest.** If a pattern has downsides, name them. If you haven't
  actually used the tool, don't write about it.
- **Be short.** If the post feels long, cut it in half and then cut it again.
  The bar is "would I read this if it weren't mine?"

## Frontmatter reference

See the schema in
[`site/src/content.config.ts`](./site/src/content.config.ts). The build will
reject invalid frontmatter. That's a feature.

## Style

- One H1 per page (the title, set via frontmatter). Start the body at H2.
- Code blocks always get a language tag.
- Prefer pasted commands over prose descriptions of commands.
- Links: use inline `[text](url)`, not reference-style.

## Licensing

By opening a PR you agree to publish under the MIT license. Co-authored
commits are welcome and encouraged.

## Questions

Open an issue with the `question` label. Keep it short — it's more likely to
get a useful answer.
