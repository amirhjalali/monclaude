---
title: ripgrep
description: The search tool Claude reaches for under the hood — and the one you should reach for too.
pubDate: 2026-02-10
repo: "https://github.com/BurntSushi/ripgrep"
homepage: "https://github.com/BurntSushi/ripgrep"
tags: ["search", "cli", "indispensable"]
featured: true
---

If you only install one tool on top of your base system, make it `ripgrep`.
Claude's `Grep` tool is built on it, and the moment you switch from `grep` to
`rg` in your own workflow, two things happen:

1. Your searches get a lot faster.
2. You start running more of them, which makes you a better debugger.

## Install

```bash
# macOS
brew install ripgrep

# Debian/Ubuntu
sudo apt install ripgrep

# Arch
sudo pacman -S ripgrep

# or via cargo
cargo install ripgrep
```

## The five invocations worth memorizing

```bash
# Find a string, case-insensitive, with line numbers
rg -in "TODO"

# Restrict to a file type
rg -t ts "useEffect"

# Show N lines of context around each match
rg -C2 "panic"

# Multiline match (patterns that span lines)
rg -U "class\s+Foo[\s\S]*?method"

# Search inside compressed files (tarballs, gz)
rg -z "error" ./archive.tgz
```

## Why it pairs well with agents

Coding agents are query-hungry. When search is slow, they slow down to match.
`ripgrep` is fast enough that an Explore sub-agent can do 20 targeted searches
in the time it would take plain `grep` to do two. The result is more thorough
investigations at lower token cost.

## Gotcha

The default ignores everything in `.gitignore` (usually what you want). To
search ignored files too:

```bash
rg --no-ignore "thing"
```

## Reading

- [The `ripgrep` regex cheat sheet](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md)
- [Andrew Gallant's blog post on why ripgrep is fast](https://blog.burntsushi.net/ripgrep/)
