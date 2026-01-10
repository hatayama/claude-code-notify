#!/bin/sh
# Claude Code Notification Script
# https://github.com/hatayama/claude-code-notify
#
# Features:
# - Tab title display (iTerm2 only)
# - Click to focus the originating tab (uses session UUID for reliable targeting)
# - Non-blocking background execution
# - AI-generated contextual messages (optional, requires GEMINI_API_KEY or OPENAI_API_KEY)
#
# Requirements:
# - macOS
# - terminal-notifier (brew install terminal-notifier)
# - jq (brew install jq)
# - iTerm2 (for tab identification)
# - GEMINI_API_KEY or OPENAI_API_KEY environment variable (optional, for AI messages)

# Read JSON from stdin first (must be synchronous)
INPUT=$(cat)

# Run everything else in background to not block Claude Code
(

# Extract fields using jq (single call for efficiency)
eval "$(echo "$INPUT" | jq -r '
    @sh "INPUT_MESSAGE=\(.message // "")",
    @sh "NOTIFICATION_TYPE=\(.notification_type // "")",
    @sh "HOOK_EVENT=\(.hook_event_name // "")",
    @sh "TOOL_NAME=\(.tool_name // "")",
    @sh "TRANSCRIPT_PATH=\(.transcript_path // "")"
')"

# Extract session UUID from TERM_SESSION_ID (iTerm2 format: "w0t1p0:UUID")
SESSION_UUID=""
if [ -n "$TERM_SESSION_ID" ]; then
    SESSION_UUID=$(echo "$TERM_SESSION_ID" | cut -d':' -f2)
fi

# Get tab title via AppleScript using session UUID
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

# Check if AI message should be used for this event
# Configure via CLAUDE_NOTIFY_AI_EVENTS environment variable (comma-separated)
# Default: Stop only
should_use_ai_message() {
    EVENT="$1"
    EVENTS="${CLAUDE_NOTIFY_AI_EVENTS:-Stop}"
    case ",$EVENTS," in
        *",$EVENT,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Get default message for each event type
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

# Generate AI message (optional)
# Supports Gemini (preferred) and OpenAI APIs
# Returns empty string if AI generation fails (caller should fallback to default)
generate_ai_message() {
    if [ -z "$GEMINI_API_KEY" ] && [ -z "$OPENAI_API_KEY" ]; then
        return
    fi

    if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
        return
    fi

    CONTEXT=$(tail -10 "$TRANSCRIPT_PATH" | jq -r '.message.content[0].text // empty' 2>/dev/null | head -c 500)

    if [ -z "$CONTEXT" ]; then
        return
    fi

    # Customize via CLAUDE_NOTIFY_AI_PROMPT environment variable
    DEFAULT_PROMPT="Based on the following work content, generate a short completion notification message in one line (max 20 chars). No emoji. No explanation, just the message.

Work content:"
    PROMPT="${CLAUDE_NOTIFY_AI_PROMPT:-$DEFAULT_PROMPT}
$CONTEXT"

    ESCAPED_PROMPT=$(echo "$PROMPT" | jq -Rs .)

    # Try Gemini first (faster), then OpenAI
    if [ -n "$GEMINI_API_KEY" ]; then
        AI_MESSAGE=$(curl -s -m 5 "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"contents\": [{\"parts\": [{\"text\": $ESCAPED_PROMPT}]}],
                \"generationConfig\": {\"maxOutputTokens\": 50}
            }" 2>/dev/null | jq -r '.candidates[0].content.parts[0].text // empty' | tr '\n' ' ' | sed 's/^[[:space:]]*//' | cut -c1-50)
    elif [ -n "$OPENAI_API_KEY" ]; then
        AI_MESSAGE=$(curl -s -m 5 https://api.openai.com/v1/chat/completions \
            -H "Authorization: Bearer $OPENAI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"gpt-4o-mini\",
                \"max_tokens\": 50,
                \"messages\": [{\"role\": \"user\", \"content\": $ESCAPED_PROMPT}]
            }" 2>/dev/null | jq -r '.choices[0].message.content // empty' | head -1)
    fi

    if [ -n "$AI_MESSAGE" ]; then
        echo "$AI_MESSAGE"
    fi
}

# Determine sound based on event type
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

# Determine notification message (AI-generated or default)
NOTIFY_MESSAGE=""
if should_use_ai_message "$HOOK_EVENT"; then
    NOTIFY_MESSAGE=$(generate_ai_message)
fi
if [ -z "$NOTIFY_MESSAGE" ]; then
    NOTIFY_MESSAGE=$(get_default_message)
fi

# Show macOS notification with tab title as subtitle (click to activate iTerm2 and select session by UUID)
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

) &
