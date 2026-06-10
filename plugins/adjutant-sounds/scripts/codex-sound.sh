#!/bin/bash
set -euo pipefail

SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.codex/adjutant-sounds}"
payload="$(cat)"

extract_payload_value() {
  printf '%s' "$payload" |
    /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null ||
    true
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

if [[ "$last_message" != *'<proposed_plan>'* ]]; then
  transcript_message="$(
    last_assistant_message_from_transcript "$transcript_path"
  )"
fi

if [[ "$last_message"$'\n'"$transcript_message" == *'<proposed_plan>'* ]]; then
  sound_name="plan.wav"
elif ((RANDOM % 2)); then
  sound_name="addon.wav"
else
  sound_name="upgrade.wav"
fi

sound_path="$SOUND_DIR/$sound_name"

if [ ! -f "$sound_path" ]; then
  exit 0
fi

if [ "${ADJUTANT_SOUNDS_DEBUG:-0}" = "1" ]; then
  printf '%s\n' "$sound_path"
  exit 0
fi

/usr/bin/afplay "$sound_path" >/dev/null 2>&1 || true
