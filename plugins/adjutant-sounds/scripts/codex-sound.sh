#!/bin/bash
set -euo pipefail

SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.codex/adjutant-sounds}"
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
  local line event_type payload_type context_used

  if [ -z "$transcript_path" ] || [ ! -r "$transcript_path" ]; then
    return
  fi

  while IFS= read -r line; do
    event_type="$(printf '%s' "$line" | /usr/bin/plutil -extract type raw -o - - 2>/dev/null || true)"
    payload_type="$(printf '%s' "$line" | /usr/bin/plutil -extract payload.type raw -o - - 2>/dev/null || true)"

    if [ "$payload_type" = "token_count" ]; then
      context_used="$(printf '%s' "$line" | /usr/bin/plutil -extract payload.info.last_token_usage.input_tokens raw -o - - 2>/dev/null || true)"
    elif [ "$event_type" = "turn.completed" ]; then
      context_used="$(printf '%s' "$line" | /usr/bin/plutil -extract usage.input_tokens raw -o - - 2>/dev/null || true)"
    else
      continue
    fi

    case "$context_used" in
      ''|*[!0-9]*) continue ;;
    esac

    printf '%s' "$context_used"
    return
  done < <(/usr/bin/tail -r "$transcript_path")
}

last_assistant_message_from_transcript() {
  local transcript_path="$1"
  local line item_type payload_type role content_count text part index

  if [ -z "$transcript_path" ] || [ ! -r "$transcript_path" ]; then
    return
  fi

  while IFS= read -r line; do
    [[ "$line" == *'"response_item"'* && "$line" == *'"assistant"'* ]] ||
      continue

    item_type="$(
      printf '%s' "$line" |
        /usr/bin/plutil -extract type raw -o - - 2>/dev/null ||
        true
    )"
    payload_type="$(
      printf '%s' "$line" |
        /usr/bin/plutil -extract payload.type raw -o - - 2>/dev/null ||
        true
    )"
    role="$(
      printf '%s' "$line" |
        /usr/bin/plutil -extract payload.role raw -o - - 2>/dev/null ||
        true
    )"

    if [ "$item_type" != "response_item" ] ||
      [ "$payload_type" != "message" ] ||
      [ "$role" != "assistant" ]; then
      continue
    fi

    content_count="$(
      printf '%s' "$line" |
        /usr/bin/plutil -extract payload.content raw -o - - 2>/dev/null ||
        true
    )"
    case "$content_count" in
      ''|*[!0-9]*) continue ;;
    esac

    text=""
    index=0
    while [ "$index" -lt "$content_count" ]; do
      part="$(
        printf '%s' "$line" |
          /usr/bin/plutil \
            -extract "payload.content.$index.text" raw -o - - 2>/dev/null ||
          true
      )"
      text="${text}${part}"
      index=$((index + 1))
    done

    if [ -n "$text" ]; then
      printf '%s' "$text"
      return
    fi
  done < <(/usr/bin/tail -r "$transcript_path")
}

last_message="$(
  extract_payload_value last_assistant_message
)"
transcript_path="$(extract_payload_value transcript_path)"
transcript_message=""
context_used="$(last_context_token_count_from_transcript "$transcript_path")"
context_alert=0

if [ -f "$CONTEXT_ALERTS_FLAG" ] &&
  [ -n "$context_used" ] &&
  [ "$context_used" -ge "$CONTEXT_ALERT_THRESHOLD" ]; then
  context_alert=1
  printf '{"systemMessage":"WARNING! Context is entering the dumb zone: %s tokens."}\n' "$context_used"
fi

if [[ "$last_message" != *'<proposed_plan>'* ]]; then
  transcript_message="$(
    last_assistant_message_from_transcript "$transcript_path"
  )"
fi

if [[ "$last_message"$'\n'"$transcript_message" == *'<proposed_plan>'* ]]; then
  primary_sound_name="plan.wav"
elif ((RANDOM % 2)); then
  primary_sound_name="addon.wav"
else
  primary_sound_name="upgrade.wav"
fi

sound_paths=()

add_sound() {
  local sound_path="$SOUND_DIR/$1"

  [ -f "$sound_path" ] && sound_paths+=("$sound_path")
}

add_sound "$primary_sound_name"

if [ "$context_alert" -eq 1 ]; then
  add_sound "warning.wav"
fi

if [ "${ADJUTANT_SOUNDS_DEBUG:-0}" = "1" ]; then
  printf '%s\n' "${sound_paths[@]}"
else
  for sound_path in "${sound_paths[@]}"; do
    /usr/bin/afplay "$sound_path" >/dev/null 2>&1 || true
  done
fi
