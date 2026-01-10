#!/bin/sh
# Claude Code Notification Script (AI-Enhanced)
# https://github.com/hatayama/claude-code-notify
#
# Features:
# - All core features from notify.sh
# - AI-generated contextual messages (Claude direct output or Gemini/OpenAI fallback)
#
# Requirements:
# - macOS
# - terminal-notifier (brew install terminal-notifier)
# - jq (brew install jq)
# - iTerm2 (for tab identification)
# - GEMINI_API_KEY or OPENAI_API_KEY environment variable (optional, for AI fallback)
#
# Environment Variables:
# - CLAUDE_NOTIFY_AI_EVENTS: Comma-separated list of events to use AI messages (default: "Stop")
# - CLAUDE_NOTIFY_SHOW_PREFIX: Show hook event prefix in message (default: "false")
# - CLAUDE_NOTIFY_AI_PROMPT: Custom prompt for AI message generation

# Read JSON from stdin first (must be synchronous)
INPUT=$(cat)

# Run everything else in background to not block Claude Code
(

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/notify-common.sh"

# Check if AI message should be used for this event
should_use_ai_message() {
    EVENT="$1"
    EVENTS="${CLAUDE_NOTIFY_AI_EVENTS:-Stop}"
    case ",$EVENTS," in
        *",$EVENT,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Read Claude's direct response file if available
read_direct_response() {
    LAST_RESPONSE_FILE="/tmp/claude/last_response.txt"
    if [ -f "$LAST_RESPONSE_FILE" ]; then
        cat "$LAST_RESPONSE_FILE" | head -c 100
        rm -f "$LAST_RESPONSE_FILE"
    fi
}

# Generate AI message using Gemini or OpenAI API (fallback)
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

    DEFAULT_PROMPT="Based on the following work content, generate a short completion notification message in one line (max 20 chars). No emoji. No explanation, just the message.

Work content:"
    PROMPT="${CLAUDE_NOTIFY_AI_PROMPT:-$DEFAULT_PROMPT}
$CONTEXT"

    ESCAPED_PROMPT=$(echo "$PROMPT" | jq -Rs .)

    if [ -n "$GEMINI_API_KEY" ]; then
        GEMINI_RESPONSE=$(curl -s -m 5 "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"contents\": [{\"parts\": [{\"text\": $ESCAPED_PROMPT}]}],
                \"generationConfig\": {\"maxOutputTokens\": 50}
            }" 2>/dev/null)
        RAW_AI=$(echo "$GEMINI_RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty')
        AI_MESSAGE=$(printf '%s' "$RAW_AI" | tr '\n' ' ' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | cut -c1-50)
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

# Initialize
parse_input
get_session_uuid
get_tab_title
determine_sound

# Determine notification message
# Priority: 1) Direct response file, 2) AI-generated, 3) Default
NOTIFY_MESSAGE=""
NOTIFY_MESSAGE=$(read_direct_response)
if [ -z "$NOTIFY_MESSAGE" ] && should_use_ai_message "$HOOK_EVENT"; then
    NOTIFY_MESSAGE=$(generate_ai_message)
fi
if [ -z "$NOTIFY_MESSAGE" ]; then
    NOTIFY_MESSAGE=$(get_default_message)
fi

# Add prefix if enabled
add_prefix_if_enabled

# Show notification
show_notification

) &
