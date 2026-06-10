#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOUND_DIR="${ADJUTANT_SOUNDS_DIR:-$HOME/.codex/adjutant-sounds}"

sound_name="$(
  /usr/bin/osascript -l JavaScript "$SCRIPT_DIR/select-sound.js" 2>/dev/null ||
    printf '%s\n' "addon.wav"
)"

case "$sound_name" in
  plan.wav|addon.wav|upgrade.wav) ;;
  *) sound_name="addon.wav" ;;
esac

sound_path="$SOUND_DIR/$sound_name"

if [ ! -f "$sound_path" ]; then
  exit 0
fi

if [ "${ADJUTANT_SOUNDS_DEBUG:-0}" = "1" ]; then
  printf '%s\n' "$sound_path"
  exit 0
fi

/usr/bin/afplay "$sound_path" >/dev/null 2>&1 || true

