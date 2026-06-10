#!/bin/bash
set -euo pipefail

SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.codex/adjutant-sounds}"
payload="$(cat)"

last_message="$(
  printf '%s' "$payload" |
    /usr/bin/plutil -extract last_assistant_message raw -o - - 2>/dev/null ||
    true
)"

if printf '%s' "$last_message" | /usr/bin/grep -qF '<proposed_plan>'; then
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
