#!/bin/sh
# Claude Code Notification Script
# https://github.com/hatayama/claude-code-notify
#
# Features:
# - Tab number display (iTerm2 only)
# - Click to focus the originating tab
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

# Extract fields using jq
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty')
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Get tab info from TERM_SESSION_ID (iTerm2)
get_tab_info() {
    # iTerm2: TERM_SESSION_ID format is "w0t1p0:UUID" (window, tab, pane)
    if [ -n "$TERM_SESSION_ID" ]; then
        SESSION_INFO=$(echo "$TERM_SESSION_ID" | cut -d':' -f1)
        TAB_NUM=$(echo "$SESSION_INFO" | sed 's/.*t\([0-9]*\).*/\1/')
        TAB_NUM=$((TAB_NUM + 1))
        echo "*** ${TAB_NUM} ***"
        return
    fi

    echo ""
}

# Get tab number for iTerm2 tab selection
get_tab_num() {
    if [ -n "$TERM_SESSION_ID" ]; then
        SESSION_INFO=$(echo "$TERM_SESSION_ID" | cut -d':' -f1)
        TAB_NUM=$(echo "$SESSION_INFO" | sed 's/.*t\([0-9]*\).*/\1/')
        echo $((TAB_NUM + 1))
    fi
}

TAB_TITLE=$(get_tab_info)
TAB_NUM=$(get_tab_num)

# Generate AI message for Stop event (optional)
# Supports Gemini (preferred) and OpenAI APIs
generate_ai_message() {
    # If no API key, return default message
    if [ -z "$GEMINI_API_KEY" ] && [ -z "$OPENAI_API_KEY" ]; then
        echo "Task completed"
        return
    fi

    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

    if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
        echo "Task completed"
        return
    fi

    CONTEXT=$(tail -10 "$TRANSCRIPT_PATH" | jq -r '.message.content[0].text // empty' 2>/dev/null | head -c 500)

    if [ -z "$CONTEXT" ]; then
        echo "Task completed"
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
            }" 2>/dev/null | jq -r '.candidates[0].content.parts[0].text // empty' | head -1)
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
    else
        echo "Task completed"
    fi
}

# Determine sound and message based on event type
case "$HOOK_EVENT" in
    "Stop")
        SOUND="${CLAUDE_NOTIFY_SOUND_STOP:-Funk}"
        MESSAGE=$(generate_ai_message)
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
        MESSAGE="${MESSAGE:-Notification}"
        ;;
    "PermissionRequest")
        SOUND="${CLAUDE_NOTIFY_SOUND_PERMISSION:-Hero}"
        if [ -n "$TOOL_NAME" ]; then
            MESSAGE="Permission: ${TOOL_NAME}"
        else
            MESSAGE="${MESSAGE:-Permission required}"
        fi
        ;;
    *)
        SOUND="${CLAUDE_NOTIFY_SOUND_STOP:-Funk}"
        MESSAGE="${MESSAGE:-Claude Code notification}"
        ;;
esac

# Show macOS notification with tab title as subtitle (click to activate iTerm2 and select tab)
if [ -n "$TAB_NUM" ]; then
    EXECUTE_CMD="osascript -e 'tell application \"iTerm2\" to activate' -e 'tell application \"iTerm2\" to tell current window to select tab ${TAB_NUM}'"
    terminal-notifier -message "$MESSAGE" -title "Claude Code" -subtitle "$TAB_TITLE" -sound "$SOUND" -execute "$EXECUTE_CMD"
elif [ -n "$TAB_TITLE" ]; then
    terminal-notifier -message "$MESSAGE" -title "Claude Code" -subtitle "$TAB_TITLE" -sound "$SOUND" -activate com.googlecode.iterm2
else
    terminal-notifier -message "$MESSAGE" -title "Claude Code" -sound "$SOUND" -activate com.googlecode.iterm2
fi

) &
