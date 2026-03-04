#!/bin/sh
# Claude Code Notify - Installer
# Idempotent: safe to re-run for updates (git pull && ./install.sh)
# Zero external dependencies (uses python3 and osascript, both macOS built-in)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

printf '🔔 Claude Code Notify - Installer\n\n'

# --- 1. Copy hook scripts ---
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/tab-title.sh" "$HOOKS_DIR/tab-title.sh"
cp "$SCRIPT_DIR/hooks/notify.sh" "$HOOKS_DIR/notify.sh"
chmod +x "$HOOKS_DIR/tab-title.sh" "$HOOKS_DIR/notify.sh"
printf '✓ Hook scripts installed to %s\n' "$HOOKS_DIR"

# --- 2. Merge settings.json ---
if [ ! -f "$SETTINGS_FILE" ]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo '{}' > "$SETTINGS_FILE"
fi

python3 << 'PYTHON_SCRIPT'
import json
import sys
import os

settings_path = os.path.expanduser("~/.claude/settings.json")

with open(settings_path, "r") as f:
    settings = json.load(f)

# Ensure top-level keys exist
if "env" not in settings:
    settings["env"] = {}
if "hooks" not in settings:
    settings["hooks"] = {}

# Set env to disable Claude Code's built-in terminal title
settings["env"]["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"] = "1"

# Hook entries to add
new_hooks = {
    "UserPromptSubmit": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab-title.sh on"}
            ]
        }
    ],
    "PreToolUse": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab-title.sh on"}
            ]
        }
    ],
    "Notification": [
        {
            "matcher": "permission_prompt",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab-title.sh ask"},
                {"type": "command", "command": "~/.claude/hooks/notify.sh"}
            ]
        }
    ],
    "Stop": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": "~/.claude/hooks/tab-title.sh done"},
                {"type": "command", "command": "~/.claude/hooks/notify.sh"}
            ]
        }
    ]
}

def hook_entry_exists(existing_entries, new_entry):
    """Check if an equivalent hook entry already exists."""
    new_commands = {h["command"] for h in new_entry.get("hooks", [])}
    for entry in existing_entries:
        existing_commands = {h["command"] for h in entry.get("hooks", [])}
        if entry.get("matcher") == new_entry.get("matcher") and new_commands <= existing_commands:
            return True
    return False

for event_name, entries in new_hooks.items():
    if event_name not in settings["hooks"]:
        settings["hooks"][event_name] = []

    for new_entry in entries:
        if not hook_entry_exists(settings["hooks"][event_name], new_entry):
            settings["hooks"][event_name].append(new_entry)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

PYTHON_SCRIPT

printf '✓ Hook configuration merged into %s\n' "$SETTINGS_FILE"

# --- 3. Add CLAUDE_TTY to shell profile ---
CLAUDE_TTY_LINE='export CLAUDE_TTY=$(tty)'

add_to_profile() {
    PROFILE="$1"
    if [ -f "$PROFILE" ] && grep -qF 'CLAUDE_TTY' "$PROFILE"; then
        return 0
    fi
    if [ -f "$PROFILE" ] || [ "$PROFILE" = "$HOME/.zshrc" ]; then
        printf '\n# Claude Code Notify - tab title support\n%s\n' "$CLAUDE_TTY_LINE" >> "$PROFILE"
        printf '✓ Added CLAUDE_TTY to %s\n' "$PROFILE"
        return 0
    fi
    return 1
}

PROFILE_ADDED=false
# zsh first (macOS default shell)
if add_to_profile "$HOME/.zshrc"; then
    PROFILE_ADDED=true
fi
# bash as well if .bashrc exists
if [ -f "$HOME/.bashrc" ]; then
    add_to_profile "$HOME/.bashrc"
    PROFILE_ADDED=true
fi
# bash_profile if .bash_profile exists
if [ -f "$HOME/.bash_profile" ]; then
    add_to_profile "$HOME/.bash_profile"
    PROFILE_ADDED=true
fi

if [ "$PROFILE_ADDED" = false ]; then
    printf '⚠ Could not detect shell profile. Please add manually:\n'
    printf '  %s\n' "$CLAUDE_TTY_LINE"
fi

# --- Done ---
printf '\n🎉 Installation complete!\n\n'
printf 'Tab title indicators:\n'
printf '  ⚡ Processing\n'
printf '  ✅ Complete\n'
printf '  ❓ Waiting for permission\n\n'
printf 'To activate, restart your terminal or run:\n'
printf '  source ~/.zshrc\n\n'
printf 'To update later:\n'
printf '  cd %s && git pull && ./install.sh\n' "$SCRIPT_DIR"
