#!/bin/bash
# monclaude installer
# Usage: curl -fsSL https://raw.githubusercontent.com/amirhjalali/monclaude/main/install.sh | bash
set -e

DEST="$HOME/.claude/monclaude.sh"
SETTINGS="$HOME/.claude/settings.json"
REPO_URL="https://raw.githubusercontent.com/amirhjalali/monclaude/main/monclaude.sh"

echo "Installing monclaude..."

# Download the script
curl -fsSL "$REPO_URL" -o "$DEST"
chmod +x "$DEST"
echo "  Downloaded to $DEST"

# Check for jq dependency
if ! command -v jq &>/dev/null; then
    echo ""
    echo "  WARNING: jq is required but not installed."
    echo "  Install it with: brew install jq (macOS) or apt install jq (Linux)"
    echo ""
fi

# Configure Claude Code status line
if [ -f "$SETTINGS" ]; then
    # Update existing settings
    tmp=$(mktemp)
    jq --arg cmd "$DEST" '.status_line = $cmd' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
else
    # Create settings file
    mkdir -p "$(dirname "$SETTINGS")"
    echo "{\"status_line\": \"$DEST\"}" | jq . > "$SETTINGS"
fi
echo "  Configured Claude Code status line"

echo ""
echo "Done! Restart Claude Code to see your new status line."
