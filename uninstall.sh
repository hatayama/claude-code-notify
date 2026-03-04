#!/bin/sh
# Claude Code Notify - Uninstaller (thin wrapper)
# Downloads and runs uninstall.py if not running from a local clone.
set -e

REPO_RAW="https://raw.githubusercontent.com/hatayama/claude-code-notify/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/uninstall.py" ]; then
    python3 "$SCRIPT_DIR/uninstall.py"
else
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf "$WORK_DIR"' EXIT
    curl -fsSL "$REPO_RAW/uninstall.py" -o "$WORK_DIR/uninstall.py"
    python3 "$WORK_DIR/uninstall.py"
fi
