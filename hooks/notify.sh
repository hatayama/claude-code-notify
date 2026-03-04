#!/bin/sh
# Claude Code desktop notification script (macOS)
# Reads JSON context from stdin and displays notifications with event-specific sounds.
# Zero external dependencies - uses only osascript (macOS built-in).
# Runs notification in background to avoid blocking Claude Code.
#
# Usage: notify.sh [options]
#   -t, --title TITLE      Override notification title
#   -m, --message MESSAGE  Override notification message
#   -s, --sound SOUND      Override notification sound
#
# Environment variables:
#   CLAUDE_NOTIFY_SOUND_STOP         Sound for Stop events (default: Funk)
#   CLAUDE_NOTIFY_SOUND_PERMISSION   Sound for permission prompts (default: Hero)
#   CLAUDE_NOTIFY_SOUND_NOTIFICATION Sound for other notifications (default: Submarine)
#   CLAUDE_NOTIFY_SOUND_DEFAULT      Default sound (default: Funk)

ARG_TITLE=""
ARG_MESSAGE=""
ARG_SOUND=""

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--title)   ARG_TITLE="$2";   shift 2 ;;
        -m|--message) ARG_MESSAGE="$2"; shift 2 ;;
        -s|--sound)   ARG_SOUND="$2";   shift 2 ;;
        *)            shift ;;
    esac
done

INPUT=$(cat)

(

json_get() {
    printf '%s' "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1],''))" "$1" 2>/dev/null
}

HOOK_EVENT=$(json_get hook_event_name)
NOTIFICATION_TYPE=$(json_get notification_type)
JSON_MESSAGE=$(json_get message)
TOOL_NAME=$(json_get tool_name)
CWD=$(json_get cwd)

DIR_NAME=$(basename "$CWD" 2>/dev/null || echo "")

case "$HOOK_EVENT" in
    "Stop")
        SOUND="${CLAUDE_NOTIFY_SOUND_STOP:-Funk}"
        MESSAGE="${JSON_MESSAGE:-Response complete}"
        TITLE="Claude Code - Complete"
        ;;
    "Notification")
        case "$NOTIFICATION_TYPE" in
            "permission_prompt")
                SOUND="${CLAUDE_NOTIFY_SOUND_PERMISSION:-Hero}"
                TITLE="Claude Code - Permission"
                ;;
            *)
                SOUND="${CLAUDE_NOTIFY_SOUND_NOTIFICATION:-Submarine}"
                TITLE="Claude Code - Notification"
                ;;
        esac
        MESSAGE="${JSON_MESSAGE:-Notification}"
        ;;
    *)
        SOUND="${CLAUDE_NOTIFY_SOUND_DEFAULT:-Funk}"
        MESSAGE="${JSON_MESSAGE:-Claude Code notification}"
        TITLE="Claude Code"
        ;;
esac

[ -n "$ARG_TITLE" ] && TITLE="$ARG_TITLE"
[ -n "$ARG_MESSAGE" ] && MESSAGE="$ARG_MESSAGE"
[ -n "$ARG_SOUND" ] && SOUND="$ARG_SOUND"

if [ -n "$DIR_NAME" ]; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"$DIR_NAME\" sound name \"$SOUND\"" 2>/dev/null || true
else
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"$SOUND\"" 2>/dev/null || true
fi

) &
