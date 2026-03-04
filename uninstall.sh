#!/bin/sh
# Claude Code Notify - Uninstaller
set -e

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

printf '🔔 Claude Code Notify - Uninstaller\n\n'

# --- 1. Remove hook scripts ---
for FILE in tab-title.sh notify.sh; do
    if [ -f "$HOOKS_DIR/$FILE" ]; then
        rm "$HOOKS_DIR/$FILE"
        printf '✓ Removed %s/%s\n' "$HOOKS_DIR" "$FILE"
    fi
done

# --- 2. Remove hook entries from settings.json ---
if [ -f "$SETTINGS_FILE" ]; then
    python3 << 'PYTHON_SCRIPT'
import json
import os

settings_path = os.path.expanduser("~/.claude/settings.json")

with open(settings_path, "r") as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
our_commands = {"~/.claude/hooks/tab-title.sh", "~/.claude/hooks/notify.sh"}

for event_name in list(hooks.keys()):
    filtered = []
    for entry in hooks[event_name]:
        entry_commands = {h.get("command", "") for h in entry.get("hooks", [])}
        # Keep entries that don't exclusively contain our commands
        if not entry_commands <= {c for c in our_commands for c in [c, c + " on", c + " done", c + " ask", c + " off"]}:
            filtered.append(entry)
    if filtered:
        hooks[event_name] = filtered
    else:
        del hooks[event_name]

# Remove env entry
env = settings.get("env", {})
if env.get("CLAUDE_CODE_DISABLE_TERMINAL_TITLE") == "1":
    del env["CLAUDE_CODE_DISABLE_TERMINAL_TITLE"]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

PYTHON_SCRIPT
    printf '✓ Removed hook configuration from %s\n' "$SETTINGS_FILE"
fi

# --- 3. Remove CLAUDE_TTY from shell profiles ---
remove_from_profile() {
    PROFILE="$1"
    if [ -f "$PROFILE" ] && grep -qF 'CLAUDE_TTY' "$PROFILE"; then
        # Remove the CLAUDE_TTY line and the comment above it
        sed -i '' '/# Claude Code Notify - tab title support/d' "$PROFILE"
        sed -i '' '/export CLAUDE_TTY/d' "$PROFILE"
        printf '✓ Removed CLAUDE_TTY from %s\n' "$PROFILE"
    fi
}

remove_from_profile "$HOME/.zshrc"
remove_from_profile "$HOME/.bashrc"
remove_from_profile "$HOME/.bash_profile"

# --- 4. Clean up marker files ---
rm -f /tmp/claude-iterm2-title-*
printf '✓ Cleaned up marker files\n'

printf '\n🎉 Uninstall complete!\n'
