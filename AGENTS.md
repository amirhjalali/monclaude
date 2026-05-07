# Repository Guidelines

## Project Shape

`monclaude` is intentionally small: `monclaude.sh` renders the Claude Code status line, `install.sh` installs and configures it, and `README.md` is the user-facing entry point. Keep the implementation dependency-light and shell-first.

## Commands

```bash
shellcheck monclaude.sh install.sh
bash -n monclaude.sh install.sh
```

## Change Rules

- Preserve macOS and Linux behavior.
- Keep installer changes idempotent.
- Do not add a package manager or build step unless the project stops being a single-script tool.
- Update `README.md` and `CHANGELOG.md` when behavior changes.
