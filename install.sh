#!/bin/bash
set -euo pipefail

readonly MARKETPLACE_SOURCE="aralot/adjutant-sounds"
readonly MARKETPLACE_NAME="adjutant-sounds"
readonly PLUGIN_NAME="adjutant-sounds"
readonly TARGET_SOUND_DIR="${HOME}/.codex/adjutant-sounds"
readonly USER_HOOKS_FILE="${HOME}/.codex/hooks.json"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "adjutant-sounds currently supports macOS only."
fi

command -v codex >/dev/null 2>&1 ||
  fail "Codex CLI was not found in PATH."

if [[ -f "$USER_HOOKS_FILE" ]] &&
  grep -Eq 'codex-sound\.sh|/\.codex/sounds([/"[:space:]]|$)' "$USER_HOOKS_FILE"; then
  cat >&2 <<EOF
Error: an existing sound hook was found in:
  $USER_HOOKS_FILE

Remove the old Stop hook manually, then run this installer again.
No changes were made.
EOF
  exit 1
fi

if [[ $# -ne 1 ]]; then
  fail "usage: ./install.sh /path/to/sound-directory"
fi

readonly SOURCE_SOUND_DIR="${1%/}"

[[ -d "$SOURCE_SOUND_DIR" ]] ||
  fail "sound directory does not exist: $SOURCE_SOUND_DIR"

for sound in plan.wav addon.wav upgrade.wav; do
  [[ -f "$SOURCE_SOUND_DIR/$sound" ]] ||
    fail "missing required sound: $SOURCE_SOUND_DIR/$sound"
done

mkdir -p "$TARGET_SOUND_DIR"
for sound in plan.wav addon.wav upgrade.wav; do
  if [[ ! "$SOURCE_SOUND_DIR/$sound" -ef "$TARGET_SOUND_DIR/$sound" ]]; then
    cp "$SOURCE_SOUND_DIR/$sound" "$TARGET_SOUND_DIR/$sound"
  fi
done
install -m 755 \
  "plugins/adjutant-sounds/scripts/codex-sound.sh" \
  "$TARGET_SOUND_DIR/codex-sound.sh"

if codex plugin marketplace list --json |
  grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${MARKETPLACE_NAME}\""; then
  codex plugin marketplace upgrade "$MARKETPLACE_NAME"
else
  codex plugin marketplace add "$MARKETPLACE_SOURCE"
fi

if codex plugin list --json |
  grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${PLUGIN_NAME}\""; then
  codex plugin remove "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
fi

codex plugin add "${PLUGIN_NAME}@${MARKETPLACE_NAME}"

cat <<EOF

Adjutant Sounds installed.

1. Restart Codex.
2. Open /hooks.
3. Review and trust the Adjutant Sounds Stop hook.
EOF
