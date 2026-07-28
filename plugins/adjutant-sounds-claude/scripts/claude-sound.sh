#!/bin/bash
set -euo pipefail

SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.claude/adjutant-sounds}"
CONTEXT_ALERTS_FLAG="$SOUND_DIR/.context-alerts-enabled"
CONTEXT_ALERT_THRESHOLD=150000
payload="$(cat)"

extract_payload_value() {
  local value

  value="$(printf '%s' "$payload" |
    /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null ||
    true)"

  case "$value" in
    '<stdin>:'*) return ;;
  esac

  printf '%s' "$value"
}

last_context_token_count_from_transcript() {
  local transcript_path="$1"
  local line event_type role input_tokens cache_creation_tokens cache_read_tokens context_used

  if [ -z "$transcript_path" ] || [ ! -r "$transcript_path" ]; then
    return
  fi

  while IFS= read -r line; do
    event_type="$(printf '%s' "$line" | /usr/bin/plutil -extract type raw -o - - 2>/dev/null || true)"
    role="$(printf '%s' "$line" | /usr/bin/plutil -extract message.role raw -o - - 2>/dev/null || true)"

    if [ "$event_type" != "assistant" ] || [ "$role" != "assistant" ]; then
      continue
    fi

    input_tokens="$(printf '%s' "$line" | /usr/bin/plutil -extract message.usage.input_tokens raw -o - - 2>/dev/null || true)"
    cache_creation_tokens="$(printf '%s' "$line" | /usr/bin/plutil -extract message.usage.cache_creation_input_tokens raw -o - - 2>/dev/null || true)"
    cache_read_tokens="$(printf '%s' "$line" | /usr/bin/plutil -extract message.usage.cache_read_input_tokens raw -o - - 2>/dev/null || true)"

    case "$cache_creation_tokens" in '<stdin>:'*) cache_creation_tokens="" ;; esac
    case "$cache_read_tokens" in '<stdin>:'*) cache_read_tokens="" ;; esac

    case "$input_tokens" in
      ''|*[!0-9]*) continue ;;
    esac

    cache_creation_tokens="${cache_creation_tokens:-0}"
    cache_read_tokens="${cache_read_tokens:-0}"

    case "$cache_creation_tokens:$cache_read_tokens" in
      *[!0-9:]*|::) continue ;;
    esac

    context_used=$((input_tokens + cache_creation_tokens + cache_read_tokens))
    printf '%s' "$context_used"
    return
  done < <(/usr/bin/tail -r "$transcript_path")
}

permission_mode="$(extract_payload_value permission_mode)"
tool_name="$(extract_payload_value tool_name)"
transcript_path="$(extract_payload_value transcript_path)"
context_used=""
context_alert=0

if [ "$tool_name" = "ExitPlanMode" ] || [ "$permission_mode" = "plan" ]; then
  primary_sound_name="plan.wav"
elif ((RANDOM % 2)); then
  primary_sound_name="addon.wav"
else
  primary_sound_name="upgrade.wav"
fi

if [ "$tool_name" = "ExitPlanMode" ]; then
  context_used=""
else
  context_used="$(last_context_token_count_from_transcript "$transcript_path")"
fi

if [ -f "$CONTEXT_ALERTS_FLAG" ] &&
  [ -n "$context_used" ] &&
  [ "$context_used" -ge "$CONTEXT_ALERT_THRESHOLD" ]; then
  context_alert=1
  printf '{"systemMessage":"WARNING! Context is entering the dumb zone: %s tokens."}\n' "$context_used"
fi

play_sound() {
  local sound_path="$SOUND_DIR/$1"

  if [ ! -f "$sound_path" ]; then
    return
  fi

  if [ "${ADJUTANT_SOUNDS_DEBUG:-0}" = "1" ]; then
    printf '%s\n' "$sound_path"
    return
  fi

  /usr/bin/afplay "$sound_path" >/dev/null 2>&1 || true
}

play_sound "$primary_sound_name"

if [ "$context_alert" -eq 1 ]; then
  play_sound "warning.wav"
fi
