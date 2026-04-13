#!/usr/bin/env node
// Scaffold a new piece of content.
//
// Usage:
//   pnpm new guide "Designing a CLAUDE.md"
//   pnpm new tool "ripgrep"
//   pnpm new prompt "Diff-first code review"

import { mkdirSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, "..");

const [, , kindRaw, ...titleParts] = process.argv;
const kind = (kindRaw || "").toLowerCase();
const title = titleParts.join(" ").trim();

const KINDS = ["guide", "tool", "prompt"];
if (!KINDS.includes(kind) || !title) {
  console.error(`Usage: pnpm new <${KINDS.join("|")}> "Title of the piece"`);
  process.exit(1);
}

const slug = title
  .toLowerCase()
  .normalize("NFKD")
  .replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/(^-|-$)/g, "");

const today = new Date().toISOString().slice(0, 10);

const collectionDir = {
  guide: "guides",
  tool: "tools",
  prompt: "prompts",
}[kind];

const targetDir = join(repoRoot, "src", "content", collectionDir);
mkdirSync(targetDir, { recursive: true });

const target = join(targetDir, `${slug}.md`);
if (existsSync(target)) {
  console.error(`${target} already exists — pick a different title or delete it first.`);
  process.exit(1);
}

const templates = {
  guide: `---
title: "${title}"
description: "One or two sentences describing what the reader will get."
pubDate: ${today}
tags: []
order: 50
draft: true
---

Write the guide here. Markdown. Headings, code blocks, links — all fair game.

## A section

Keep it specific. Paste real prompts, real diffs, real outputs.
`,
  tool: `---
title: "${title}"
description: "One or two sentences describing what the tool does and why you use it."
pubDate: ${today}
repo: ""
homepage: ""
tags: []
featured: false
draft: true
---

## Why I use it

Short pitch. What problem does it solve?

## Install

\`\`\`bash
# install instructions
\`\`\`

## Gotchas

- ...
`,
  prompt: `---
title: "${title}"
description: "One or two sentences about when to use this prompt."
pubDate: ${today}
tags: []
agent: "any"
draft: true
---

## The prompt

\`\`\`text
<paste the prompt here>
\`\`\`

## Why it works

- ...

## Variations

- ...
`,
};

writeFileSync(target, templates[kind], "utf8");

const rel = target.replace(`${repoRoot}/`, "");
console.log(`✓ Created ${rel}`);
console.log(`  Edit frontmatter (set draft: false when ready) and write the body.`);

// Open in $EDITOR if available
const editor = process.env.EDITOR;
if (editor) {
  spawn(editor, [target], { stdio: "inherit" });
}
