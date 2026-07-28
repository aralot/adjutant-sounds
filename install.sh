#!/bin/bash
set -euo pipefail

readonly MARKETPLACE_SOURCE="aralot/adjutant-sounds"
readonly MARKETPLACE_NAME="adjutant-sounds"
readonly PLUGIN_NAME="adjutant-sounds"
readonly CONTEXT_ALERTS_FLAG=".context-alerts-enabled"

readonly CODEX_TARGET_SOUND_DIR="${HOME}/.codex/adjutant-sounds"
readonly CODEX_USER_HOOKS_FILE="${HOME}/.codex/hooks.json"

readonly CLAUDE_TARGET_SOUND_DIR="${HOME}/.claude/adjutant-sounds"
readonly CLAUDE_USER_SETTINGS_FILE="${HOME}/.claude/settings.json"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local answer

  printf '%s [y/N] ' "$prompt"
  read -r answer

  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

confirm_default_yes() {
  local prompt="$1"
  local answer

  printf '%s [Y/n] ' "$prompt"
  read -r answer

  case "$answer" in
    n|N|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

copy_sounds() {
  local target_dir="$1"

  mkdir -p "$target_dir"
  for sound in plan.wav addon.wav upgrade.wav; do
    if [[ ! "$SOURCE_SOUND_DIR/$sound" -ef "$target_dir/$sound" ]]; then
      cp "$SOURCE_SOUND_DIR/$sound" "$target_dir/$sound"
    fi
  done

  if [[ "$context_alerts_enabled" -eq 1 ]]; then
    if [[ ! "$SOURCE_SOUND_DIR/warning.wav" -ef "$target_dir/warning.wav" ]]; then
      cp "$SOURCE_SOUND_DIR/warning.wav" "$target_dir/warning.wav"
    fi
    : > "$target_dir/$CONTEXT_ALERTS_FLAG"
  else
    rm -f "$target_dir/$CONTEXT_ALERTS_FLAG"
  fi
}

codex_has_legacy_sound_hook() {
  if [[ -f "$CODEX_USER_HOOKS_FILE" ]] &&
    grep -Eq 'codex-sound\.sh|/\.codex/sounds([/"[:space:]]|$)' "$CODEX_USER_HOOKS_FILE"; then
    return 0
  fi

  return 1
}

explain_legacy_codex_hook() {
  cat >&2 <<EOF
Error: an existing Codex sound hook was found in:
  $CODEX_USER_HOOKS_FILE

Remove the old Stop hook manually, then run this installer again.
No Codex changes were made.
EOF
}

claude_has_legacy_sound_hook() {
  if [[ -f "$CLAUDE_USER_SETTINGS_FILE" ]] &&
    grep -Eq 'claude-sound\.sh|adjutant-sounds|/\.claude/sounds([/"[:space:]]|$)' "$CLAUDE_USER_SETTINGS_FILE"; then
    return 0
  fi

  return 1
}

explain_legacy_claude_hook() {
  cat >&2 <<EOF
Error: an existing Claude Code sound hook was found in:
  $CLAUDE_USER_SETTINGS_FILE

Remove the old Stop hook manually, then run this installer again.
No Claude Code changes were made.
EOF
}

install_codex() {
  copy_sounds "$CODEX_TARGET_SOUND_DIR"
  install -m 755 \
    "plugins/adjutant-sounds/scripts/codex-sound.sh" \
    "$CODEX_TARGET_SOUND_DIR/codex-sound.sh"

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
}

install_claude() {
  copy_sounds "$CLAUDE_TARGET_SOUND_DIR"

  if claude plugin marketplace list --json |
    grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${MARKETPLACE_NAME}\""; then
    claude plugin marketplace update "$MARKETPLACE_NAME"
  else
    claude plugin marketplace add "$MARKETPLACE_SOURCE"
  fi

  if claude plugin list --json |
    grep -Eq "\"name\"[[:space:]]*:[[:space:]]*\"${PLUGIN_NAME}\""; then
    claude plugin update "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
  else
    claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "adjutant-sounds currently supports macOS only."
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

codex_available=0
claude_available=0
install_any=0
codex_selected=0
claude_selected=0
codex_skipped=0
claude_skipped=0
context_alerts_enabled=0

if command -v codex >/dev/null 2>&1; then
  codex_available=1
fi

if command -v claude >/dev/null 2>&1; then
  claude_available=1
fi

if [[ "$codex_available" -eq 0 && "$claude_available" -eq 0 ]]; then
  fail "neither Codex CLI nor Claude Code was found in PATH."
fi

if [[ "$codex_available" -eq 1 ]] &&
  confirm "Install Adjutant Sounds for Codex?"; then
  codex_selected=1
fi

if [[ "$claude_available" -eq 1 ]] &&
  confirm "Install Adjutant Sounds for Claude Code?"; then
  claude_selected=1
fi

if [[ "$codex_selected" -eq 0 && "$claude_selected" -eq 0 ]]; then
  cat <<EOF

No agents selected. Nothing was changed.
EOF
  exit 0
fi

if confirm_default_yes "Enable alerts when the recommended context limit is exceeded?"; then
  context_alerts_enabled=1
  [[ -f "$SOURCE_SOUND_DIR/warning.wav" ]] ||
    fail "missing required sound for context alerts: $SOURCE_SOUND_DIR/warning.wav"
fi

if [[ "$codex_selected" -eq 1 ]]; then
  if codex_has_legacy_sound_hook; then
    explain_legacy_codex_hook
    codex_skipped=1
  else
    install_codex
    install_any=1
  fi
fi

if [[ "$claude_selected" -eq 1 ]]; then
  if claude_has_legacy_sound_hook; then
    explain_legacy_claude_hook
    claude_skipped=1
  else
    install_claude
    install_any=1
  fi
fi

if [[ "$install_any" -eq 1 ]]; then
  cat <<EOF

Adjutant Sounds installed.

Restart the selected agent apps. Then review and trust the new Stop hook if
your agent asks for hook approval.
EOF
fi

if [[ "$codex_skipped" -eq 1 || "$claude_skipped" -eq 1 ]]; then
  exit 1
fi
