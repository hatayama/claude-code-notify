#!/bin/sh
# Claude Code Notify - Installer (thin wrapper)
# Downloads and runs install.py if not running from a local clone.
set -e

REPO_RAW="https://raw.githubusercontent.com/hatayama/claude-code-notify/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/install.py" ]; then
    python3 "$SCRIPT_DIR/install.py"
else
    WORK_DIR=$(mktemp -d)
    trap 'rm -rf "$WORK_DIR"' EXIT
    curl -fsSL --create-dirs "$REPO_RAW/install.py" -o "$WORK_DIR/install.py"
    curl -fsSL --create-dirs "$REPO_RAW/hooks/tab_title.py" -o "$WORK_DIR/hooks/tab_title.py"
    curl -fsSL --create-dirs "$REPO_RAW/hooks/notify.py" -o "$WORK_DIR/hooks/notify.py"
    curl -fsSL --create-dirs "$REPO_RAW/iterm2/focus_clear_prefix.py" -o "$WORK_DIR/iterm2/focus_clear_prefix.py"
    python3 "$WORK_DIR/install.py" --source-dir "$WORK_DIR"
fi
