#!/bin/bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
readonly TEST_DIR="$(mktemp -d)"

prepare_sound_dir() {
  local sound_dir="$1"

  mkdir -p "$sound_dir"
  touch "$sound_dir/addon.wav" "$sound_dir/upgrade.wav" "$sound_dir/plan.wav" "$sound_dir/warning.wav"
}

assert_contains() {
  local output="$1"
  local expected="$2"

  [[ "$output" == *"$expected"* ]] || {
    printf 'Expected output to contain: %s\nActual output:\n%s\n' "$expected" "$output" >&2
    exit 1
  }
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"

  [[ "$output" != *"$unexpected"* ]] || {
    printf 'Expected output not to contain: %s\nActual output:\n%s\n' "$unexpected" "$output" >&2
    exit 1
  }
}

assert_before() {
  local output="$1"
  local first="$2"
  local second="$3"
  local first_position second_position

  first_position="${output%%"$first"*}"
  second_position="${output%%"$second"*}"

  [[ ${#first_position} -lt ${#second_position} ]] || {
    printf 'Expected %s before %s.\nActual output:\n%s\n' "$first" "$second" "$output" >&2
    exit 1
  }
}

assert_primary_before_warning() {
  local output="$1"
  local sound_dir="$2"

  if [[ "$output" == *"$sound_dir/addon.wav"* ]]; then
    assert_before "$output" "$sound_dir/addon.wav" "$sound_dir/warning.wav"
  else
    assert_before "$output" "$sound_dir/upgrade.wav" "$sound_dir/warning.wav"
  fi
}

write_transcripts() {
  node -e '
    const fs = require("fs");
    const dir = process.argv[1];
    fs.writeFileSync(
      `${dir}/codex-high.jsonl`,
      `${JSON.stringify({type: "event_msg", payload: {type: "token_count", info: {last_token_usage: {input_tokens: 150123}}}})}\n`,
    );
    fs.writeFileSync(
      `${dir}/claude-high.jsonl`,
      `${JSON.stringify({type: "assistant", message: {role: "assistant", usage: {input_tokens: 7, cache_creation_input_tokens: 50000, cache_read_input_tokens: 100116}}})}\n`,
    );
    fs.writeFileSync(
      `${dir}/codex-low.jsonl`,
      `${JSON.stringify({type: "event_msg", payload: {type: "token_count", info: {last_token_usage: {input_tokens: 149999}}}})}\n`,
    );
    fs.writeFileSync(
      `${dir}/codex-boundary.jsonl`,
      `${JSON.stringify({type: "event_msg", payload: {type: "token_count", info: {last_token_usage: {input_tokens: 150000}}}})}\n`,
    );
    fs.writeFileSync(
      `${dir}/codex-completed.jsonl`,
      `${JSON.stringify({type: "turn.completed", usage: {input_tokens: 150321}})}\n`,
    );
    fs.writeFileSync(
      `${dir}/claude-no-cache.jsonl`,
      `${JSON.stringify({type: "assistant", message: {role: "assistant", usage: {input_tokens: 150000}}})}\n`,
    );
  ' "$TEST_DIR"
}

prepare_sound_dir "$TEST_DIR/codex"
prepare_sound_dir "$TEST_DIR/claude"
write_transcripts

touch "$TEST_DIR/codex/.context-alerts-enabled" "$TEST_DIR/claude/.context-alerts-enabled"

codex_high_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_contains "$codex_high_output" 'WARNING! Context is entering the dumb zone: 150123 tokens.'
assert_contains "$codex_high_output" "$TEST_DIR/codex/warning.wav"
assert_primary_before_warning "$codex_high_output" "$TEST_DIR/codex"

claude_high_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/claude-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/claude" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds-claude/scripts/claude-sound.sh"
)"
assert_contains "$claude_high_output" 'WARNING! Context is entering the dumb zone: 150123 tokens.'
assert_contains "$claude_high_output" "$TEST_DIR/claude/warning.wav"
assert_primary_before_warning "$claude_high_output" "$TEST_DIR/claude"

codex_plan_output="$(
  node -e 'process.stdout.write(JSON.stringify({last_assistant_message: "<proposed_plan>", transcript_path: process.argv[1]}))' "$TEST_DIR/codex-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_contains "$codex_plan_output" "$TEST_DIR/codex/plan.wav"
assert_contains "$codex_plan_output" "$TEST_DIR/codex/warning.wav"
assert_before "$codex_plan_output" "$TEST_DIR/codex/plan.wav" "$TEST_DIR/codex/warning.wav"

claude_plan_output="$(
  node -e 'process.stdout.write(JSON.stringify({permission_mode: "plan", transcript_path: process.argv[1]}))' "$TEST_DIR/claude-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/claude" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds-claude/scripts/claude-sound.sh"
)"
assert_contains "$claude_plan_output" "$TEST_DIR/claude/plan.wav"
assert_contains "$claude_plan_output" "$TEST_DIR/claude/warning.wav"
assert_before "$claude_plan_output" "$TEST_DIR/claude/plan.wav" "$TEST_DIR/claude/warning.wav"

claude_exit_plan_output="$(
  node -e 'process.stdout.write(JSON.stringify({tool_name: "ExitPlanMode", transcript_path: process.argv[1]}))' "$TEST_DIR/claude-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/claude" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds-claude/scripts/claude-sound.sh"
)"
assert_contains "$claude_exit_plan_output" "$TEST_DIR/claude/plan.wav"
assert_not_contains "$claude_exit_plan_output" "$TEST_DIR/claude/warning.wav"
assert_not_contains "$claude_exit_plan_output" 'WARNING! Context is entering the dumb zone'

claude_no_cache_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/claude-no-cache.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/claude" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds-claude/scripts/claude-sound.sh"
)"
assert_contains "$claude_no_cache_output" 'WARNING! Context is entering the dumb zone: 150000 tokens.'

rm "$TEST_DIR/codex/.context-alerts-enabled"
codex_disabled_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_not_contains "$codex_disabled_output" 'WARNING! Context is entering the dumb zone'
assert_not_contains "$codex_disabled_output" "$TEST_DIR/codex/warning.wav"

touch "$TEST_DIR/codex/.context-alerts-enabled"
codex_low_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-low.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_not_contains "$codex_low_output" 'WARNING! Context is entering the dumb zone'
assert_not_contains "$codex_low_output" "$TEST_DIR/codex/warning.wav"

codex_boundary_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-boundary.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_contains "$codex_boundary_output" 'WARNING! Context is entering the dumb zone: 150000 tokens.'

codex_completed_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-completed.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_contains "$codex_completed_output" 'WARNING! Context is entering the dumb zone: 150321 tokens.'

rm "$TEST_DIR/codex/warning.wav"
codex_missing_warning_output="$(
  node -e 'process.stdout.write(JSON.stringify({transcript_path: process.argv[1]}))' "$TEST_DIR/codex-high.jsonl" |
    ADJUTANT_SOUNDS_DIR="$TEST_DIR/codex" ADJUTANT_SOUNDS_DEBUG=1 \
      bash "$ROOT_DIR/plugins/adjutant-sounds/scripts/codex-sound.sh"
)"
assert_contains "$codex_missing_warning_output" 'WARNING! Context is entering the dumb zone: 150123 tokens.'
assert_not_contains "$codex_missing_warning_output" "$TEST_DIR/codex/warning.wav"

mkdir -p "$TEST_DIR/install-bin" "$TEST_DIR/install-sounds"
touch "$TEST_DIR/install-sounds/plan.wav" "$TEST_DIR/install-sounds/addon.wav" "$TEST_DIR/install-sounds/upgrade.wav"
node -e 'const fs=require("fs"); const path=process.argv[1]; fs.writeFileSync(path, "#!/bin/bash\\nexit 0\\n", {mode: 0o755})' "$TEST_DIR/install-bin/codex"

if printf 'y\n\n' | HOME="$TEST_DIR/install-home" PATH="$TEST_DIR/install-bin:/usr/bin:/bin" \
  bash "$ROOT_DIR/install.sh" "$TEST_DIR/install-sounds" >"$TEST_DIR/missing-warning-output" 2>&1; then
  printf 'Installer unexpectedly succeeded without warning.wav.\n' >&2
  exit 1
fi
assert_contains "$(<"$TEST_DIR/missing-warning-output")" 'missing required sound for context alerts'
[[ ! -e "$TEST_DIR/install-home/.codex/adjutant-sounds" ]] || {
  printf 'Installer created target files before validating warning.wav.\n' >&2
  exit 1
}

touch "$TEST_DIR/install-sounds/warning.wav"
printf 'y\n\n' | HOME="$TEST_DIR/install-home" PATH="$TEST_DIR/install-bin:/usr/bin:/bin" \
  bash "$ROOT_DIR/install.sh" "$TEST_DIR/install-sounds" >/dev/null
[[ -f "$TEST_DIR/install-home/.codex/adjutant-sounds/warning.wav" ]]
[[ -f "$TEST_DIR/install-home/.codex/adjutant-sounds/.context-alerts-enabled" ]]

printf 'y\nn\n' | HOME="$TEST_DIR/install-home" PATH="$TEST_DIR/install-bin:/usr/bin:/bin" \
  bash "$ROOT_DIR/install.sh" "$TEST_DIR/install-sounds" >/dev/null
[[ ! -e "$TEST_DIR/install-home/.codex/adjutant-sounds/.context-alerts-enabled" ]]

printf 'Sound hook tests passed.\n'
