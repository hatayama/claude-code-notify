#!/bin/sh
# Update terminal tab title to reflect Claude Code working state.
# Usage: tab-title.sh on|off|ask|done
#
# "on"   -> prefix title with ⚡ (processing)
# "done" -> prefix title with ✅ (completed)
# "ask"  -> prefix title with ❓ (waiting for permission)
# "off"  -> show title without prefix
#
# Requires CLAUDE_TTY environment variable (e.g. export CLAUDE_TTY=$(tty))
# Writes a marker file so external scripts can read the current state.

INPUT=$(cat)

ACTION="${1:-on}"

TARGET_TTY="${CLAUDE_TTY:-}"
[ -z "$TARGET_TTY" ] && exit 0

CWD=$(printf '%s' "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
[ -z "$CWD" ] && CWD="${PWD:-}"
[ -z "$CWD" ] && exit 0

GIT_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ]; then
    TITLE=$(basename "$GIT_ROOT")
else
    TITLE=$(basename "$CWD")
fi

MARKER_FILE="/tmp/claude-iterm2-title-$(echo "$TARGET_TTY" | tr '/' '-')"

case "$ACTION" in
    on)
        printf '\033]0;⚡%s\007' "$TITLE" > "$TARGET_TTY" 2>/dev/null
        printf '%s\n%s' "on" "$TITLE" > "$MARKER_FILE"
        ;;
    done)
        printf '\033]0;✅%s\007' "$TITLE" > "$TARGET_TTY" 2>/dev/null
        printf '%s\n%s' "done" "$TITLE" > "$MARKER_FILE"
        ;;
    ask)
        printf '\033]0;❓%s\007' "$TITLE" > "$TARGET_TTY" 2>/dev/null
        printf '%s\n%s' "ask" "$TITLE" > "$MARKER_FILE"
        ;;
    *)
        printf '\033]0;%s\007' "$TITLE" > "$TARGET_TTY" 2>/dev/null
        rm -f "$MARKER_FILE"
        ;;
esac
