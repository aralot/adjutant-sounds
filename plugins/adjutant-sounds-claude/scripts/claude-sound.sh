#!/bin/bash
set -euo pipefail

SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.claude/adjutant-sounds}"
payload="$(cat)"

extract_payload_value() {
  printf '%s' "$payload" |
    /usr/bin/plutil -extract "$1" raw -o - - 2>/dev/null ||
    true
}

permission_mode="$(extract_payload_value permission_mode)"
tool_name="$(extract_payload_value tool_name)"

if [ "$tool_name" = "ExitPlanMode" ] || [ "$permission_mode" = "plan" ]; then
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
