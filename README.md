# Adjutant Sounds

Voice notifications for [OpenAI Codex](https://developers.openai.com/codex/)
and [Claude Code](https://code.claude.com/) on macOS.

When an agent turn stops:

- `plan.wav` plays after a planning response.
  - Codex detects `<proposed_plan>` in the response or transcript.
  - Claude Code detects `permission_mode: "plan"` in the Stop hook payload.
- `addon.wav` or `upgrade.wav` is selected randomly for every other response.

The repository does not contain audio files. You provide the three WAV files
during installation.

## Requirements

- macOS
- Codex CLI and/or Claude Code
- Three files named exactly:
  - `plan.wav`
  - `addon.wav`
  - `upgrade.wav`

The runtime is Bash plus macOS system commands: `plutil` and `afplay`.

## Sound pack

Download the sound pack from Telegram:

https://t.me/zhirkovexe/20

The files linked outside this repository are not part of this project or its
MIT license. Make sure you have the right to use and distribute any audio you
download.

### По-русски

Скачайте из Telegram-поста три файла: `plan.wav`, `addon.wav` и
`upgrade.wav`. Ссылка: https://t.me/zhirkovexe/20

## Install

Clone the repository and pass the directory containing the three WAV files to
the installer:

```sh
git clone https://github.com/aralot/adjutant-sounds.git
cd adjutant-sounds
./install.sh ~/Downloads/adjutant-sounds
```

The installer detects `codex` and `claude` in `PATH`, then asks before
installing each integration:

```text
Install Adjutant Sounds for Codex? [y/N]
Install Adjutant Sounds for Claude Code? [y/N]
```

After installation, restart the selected agent apps. Review and trust the new
Stop hook if the agent asks for hook approval.

The installer copies sounds and hook scripts to:

```text
~/.codex/adjutant-sounds/
~/.claude/adjutant-sounds/
```

It also registers the `aralot/adjutant-sounds` marketplace and installs the
`adjutant-sounds` plugin for each selected agent.

## Existing Codex sound hook

The installer stops the Codex installation when it detects the previous manual
sound hook in `~/.codex/hooks.json`.

Remove the old Stop hook that runs `codex-sound.sh` or references
`~/.codex/sounds`, then run the installer again. Other hooks in the same file
can remain.

## Existing Claude Code sound hook

The installer stops the Claude Code installation when it detects a previous
manual sound hook in `~/.claude/settings.json`.

Remove the old Stop hook that runs `claude-sound.sh` or references
`~/.claude/sounds` or `~/.claude/adjutant-sounds`, then run the installer
again. Other hooks in the same file can remain.

Project-level Claude Code hooks are not scanned. They are scoped to a specific
project, while this installer installs the global plugin.

## Update

Pull the latest changes and run the installer again:

```sh
git pull
./install.sh ~/Downloads/adjutant-sounds
```

Restart the selected agent apps after the update. Changed hooks may need to be
trusted again.

## Uninstall

Codex:

```sh
codex plugin remove adjutant-sounds@adjutant-sounds
codex plugin marketplace remove adjutant-sounds
rm -rf ~/.codex/adjutant-sounds
```

Claude Code:

```sh
claude plugin uninstall adjutant-sounds@adjutant-sounds
claude plugin marketplace remove adjutant-sounds
rm -rf ~/.claude/adjutant-sounds
```

Restart the agent after uninstalling.

## Troubleshooting

- No sound: check that the selected agent has all three WAV files in its sound
  directory.
- Hook failed with code 127 in Codex: update to version 1.0.2 or newer and
  rerun the installer.
- A Codex plan plays a completion sound: update to version 1.0.3 or newer and
  rerun the installer.
- Hook is not running: review and trust or enable the Stop hook in the agent.
- Two sounds play in Codex: remove the old manual Stop hook from
  `~/.codex/hooks.json`.
- Two sounds play in Claude Code: remove any project-level manual Stop hook
  from `.claude/settings.json` or `.claude/settings.local.json`.
- Custom sound location: set `ADJUTANT_SOUNDS_DIR` for the agent process.
- Inspect the selected file without playing it: set
  `ADJUTANT_SOUNDS_DEBUG=1`.

## License and trademarks

The source code is available under the [MIT License](LICENSE).

Audio files are not included and are not covered by the MIT License. This is
an independent fan project and is not affiliated with or endorsed by OpenAI,
Anthropic, Blizzard Entertainment, or the StarCraft franchise. All product
names and trademarks belong to their respective owners.
