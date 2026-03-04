#!/bin/sh
# Claude Code Notify - Installer (thin wrapper)
# Downloads and runs install.py if not running from a local clone.
set -e

REPO_RAW="https://raw.githubusercontent.com/hatayama/claude-code-notify/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/install.py" ]; then
    python3 "$SCRIPT_DIR/install.py"
else
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT
    mkdir -p "$TMPDIR/hooks"
    curl -fsSL "$REPO_RAW/install.py" -o "$TMPDIR/install.py"
    curl -fsSL "$REPO_RAW/hooks/tab_title.py" -o "$TMPDIR/hooks/tab_title.py"
    curl -fsSL "$REPO_RAW/hooks/notify.py" -o "$TMPDIR/hooks/notify.py"
    python3 "$TMPDIR/install.py" --source-dir "$TMPDIR"
fi
