#!/bin/sh
# Claude Code Notification - Common Utilities
# https://github.com/hatayama/claude-code-notify
#
# This file contains shared functions used by notify.sh and notify-ai.sh
# Do not execute this file directly - it should be sourced by other scripts

# Parse JSON input and extract fields
# Sets: INPUT_MESSAGE, NOTIFICATION_TYPE, HOOK_EVENT, TOOL_NAME, TRANSCRIPT_PATH
parse_input() {
    eval "$(echo "$INPUT" | jq -r '
        @sh "INPUT_MESSAGE=\(.message // "")",
        @sh "NOTIFICATION_TYPE=\(.notification_type // "")",
        @sh "HOOK_EVENT=\(.hook_event_name // "")",
        @sh "TOOL_NAME=\(.tool_name // "")",
        @sh "TRANSCRIPT_PATH=\(.transcript_path // "")"
    ')"
}

# Extract session UUID from TERM_SESSION_ID (iTerm2 format: "w0t1p0:UUID")
# Sets: SESSION_UUID
get_session_uuid() {
    SESSION_UUID=""
    if [ -n "$TERM_SESSION_ID" ]; then
        SESSION_UUID=$(echo "$TERM_SESSION_ID" | cut -d':' -f2)
    fi
}

# Get tab title via AppleScript using session UUID
# Requires: SESSION_UUID to be set
# Sets: TAB_TITLE
get_tab_title() {
    TAB_TITLE=""
    if [ -n "$SESSION_UUID" ]; then
        TAB_TITLE=$(osascript -e "
            tell application \"iTerm2\"
                repeat with aWindow in windows
                    repeat with aTab in tabs of aWindow
                        repeat with aSession in sessions of aTab
                            if unique id of aSession is \"$SESSION_UUID\" then
                                return name of aSession
                            end if
                        end repeat
                    end repeat
                end repeat
            end tell
        " 2>/dev/null)
    fi
}

# Get default message for each event type
# Requires: HOOK_EVENT, INPUT_MESSAGE, TOOL_NAME to be set
get_default_message() {
    case "$HOOK_EVENT" in
        "Stop") echo "Task completed" ;;
        "SubagentStop") echo "Subagent completed" ;;
        "Notification") echo "${INPUT_MESSAGE:-Notification}" ;;
        "PermissionRequest") echo "Permission: ${TOOL_NAME:-required}" ;;
        "PreToolUse") echo "Tool: ${TOOL_NAME}" ;;
        "PostToolUse") echo "Tool done: ${TOOL_NAME}" ;;
        "UserPromptSubmit") echo "Prompt submitted" ;;
        "PreCompact") echo "Compacting..." ;;
        "SessionStart") echo "Session started" ;;
        "SessionEnd") echo "Session ended" ;;
        *) echo "Claude Code notification" ;;
    esac
}

# Determine sound based on event type
# Requires: HOOK_EVENT, NOTIFICATION_TYPE to be set
# Sets: SOUND
determine_sound() {
    case "$HOOK_EVENT" in
        "Stop"|"SubagentStop")
            SOUND="${CLAUDE_NOTIFY_SOUND_STOP:-Funk}"
            ;;
        "PermissionRequest")
            SOUND="${CLAUDE_NOTIFY_SOUND_PERMISSION:-Hero}"
            ;;
        "Notification")
            case "$NOTIFICATION_TYPE" in
                "permission_prompt")
                    SOUND="${CLAUDE_NOTIFY_SOUND_PERMISSION:-Hero}"
                    ;;
                *)
                    SOUND="${CLAUDE_NOTIFY_SOUND_NOTIFICATION:-Submarine}"
                    ;;
            esac
            ;;
        *)
            SOUND="${CLAUDE_NOTIFY_SOUND_DEFAULT:-default}"
            ;;
    esac
}

# Add hook event prefix if enabled (escape '[' for terminal-notifier)
# Requires: NOTIFY_MESSAGE, HOOK_EVENT to be set
# Modifies: NOTIFY_MESSAGE
add_prefix_if_enabled() {
    if [ "${CLAUDE_NOTIFY_SHOW_PREFIX:-false}" = "true" ]; then
        NOTIFY_MESSAGE="\\[$HOOK_EVENT] $NOTIFY_MESSAGE"
    fi
}

# Show macOS notification with tab title as subtitle
# Click action: activate iTerm2 and select session by UUID
# Requires: NOTIFY_MESSAGE, TAB_TITLE, SOUND, SESSION_UUID to be set
show_notification() {
    if [ -n "$SESSION_UUID" ]; then
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
        terminal-notifier -message "$NOTIFY_MESSAGE" -title "Claude Code" -subtitle "$TAB_TITLE" -sound "$SOUND" -execute "$EXECUTE_CMD"
    elif [ -n "$TAB_TITLE" ]; then
        terminal-notifier -message "$NOTIFY_MESSAGE" -title "Claude Code" -subtitle "$TAB_TITLE" -sound "$SOUND" -activate com.googlecode.iterm2
    else
        terminal-notifier -message "$NOTIFY_MESSAGE" -title "Claude Code" -sound "$SOUND" -activate com.googlecode.iterm2
    fi
}
