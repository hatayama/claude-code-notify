#!/bin/sh
# Claude Code desktop notification script (macOS)
# Reads JSON context from stdin and displays notifications with event-specific sounds.
# Uses terminal-notifier if available (click-to-focus support),
# falls back to osascript (macOS built-in). No hard dependencies.
# Runs notification in background to avoid blocking Claude Code.
#
# Usage: notify.sh [options]
#   -t, --title TITLE      Override notification title
#   -m, --message MESSAGE  Override notification message
#   -s, --sound SOUND      Override notification sound
#   -a, --activate ID      App bundle ID to activate on click (auto-detected if omitted)
#
# Environment variables:
#   CLAUDE_NOTIFY_SOUND_STOP         Sound for Stop events (default: Funk)
#   CLAUDE_NOTIFY_SOUND_PERMISSION   Sound for permission prompts (default: Hero)
#   CLAUDE_NOTIFY_SOUND_NOTIFICATION Sound for other notifications (default: Submarine)
#   CLAUDE_NOTIFY_SOUND_DEFAULT      Default sound (default: Funk)

ARG_TITLE=""
ARG_MESSAGE=""
ARG_SOUND=""
ARG_ACTIVATE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--title)    ARG_TITLE="$2";    shift 2 ;;
        -m|--message)  ARG_MESSAGE="$2";  shift 2 ;;
        -s|--sound)    ARG_SOUND="$2";    shift 2 ;;
        -a|--activate) ARG_ACTIVATE="$2"; shift 2 ;;
        *)             shift ;;
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

# Auto-detect terminal app for click-to-activate
if [ -z "$ARG_ACTIVATE" ] && [ -n "$TERM_PROGRAM" ]; then
    case "$TERM_PROGRAM" in
        ghostty)       ARG_ACTIVATE="com.mitchellh.ghostty" ;;
        iTerm.app)     ARG_ACTIVATE="com.googlecode.iterm2" ;;
        Apple_Terminal) ARG_ACTIVATE="com.apple.Terminal" ;;
        vscode)        ARG_ACTIVATE="com.microsoft.VSCode" ;;
    esac
fi

# Get iTerm2 session UUID for tab-level focus
SESSION_UUID=""
if [ -n "$TERM_SESSION_ID" ]; then
    SESSION_UUID=$(echo "$TERM_SESSION_ID" | cut -d':' -f2)
fi

if command -v terminal-notifier >/dev/null 2>&1; then
    if [ -n "$SESSION_UUID" ]; then
        # iTerm2: click notification to focus the exact tab via session UUID
        EXECUTE_CMD="osascript -e 'tell application \"iTerm2\"
            activate
            repeat with aWindow in windows
                repeat with aTab in tabs of aWindow
                    repeat with aSession in sessions of aTab
                        if unique id of aSession is \"$SESSION_UUID\" then
                            select aWindow
                            select aTab
                            select aSession
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell'"
        if [ -n "$DIR_NAME" ]; then
            terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -subtitle "$DIR_NAME" -execute "$EXECUTE_CMD"
        else
            terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -execute "$EXECUTE_CMD"
        fi
    else
        if [ -n "$DIR_NAME" ]; then
            terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" -subtitle "$DIR_NAME" ${ARG_ACTIVATE:+-activate "$ARG_ACTIVATE"}
        else
            terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound "$SOUND" ${ARG_ACTIVATE:+-activate "$ARG_ACTIVATE"}
        fi
    fi
else
    if [ -n "$DIR_NAME" ]; then
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"$DIR_NAME\" sound name \"$SOUND\"" 2>/dev/null || true
    else
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"$SOUND\"" 2>/dev/null || true
    fi
fi

) &
