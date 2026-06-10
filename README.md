# Adjutant Sounds

Voice notifications for [OpenAI Codex](https://developers.openai.com/codex/)
on macOS.

When a Codex turn stops:

- `plan.wav` plays after a response containing `<proposed_plan>`.
- `addon.wav` or `upgrade.wav` is selected randomly for every other response.

The repository does not contain audio files. You provide the three WAV files
during installation.

## Requirements

- macOS
- Codex CLI with plugin and hook support
- Three files named exactly:
  - `plan.wav`
  - `addon.wav`
  - `upgrade.wav`

The runtime is a single Bash script using the macOS system `plutil` and
`afplay` commands. Node.js, JavaScript, `jq`, Homebrew, and other runtime
dependencies are not required.

## Sound pack

Download the sound pack from Telegram:

**TODO: add the public Telegram post URL before release.**

The files linked outside this repository are not part of this project or its
MIT license. Make sure you have the right to use and distribute any audio you
download.

### По-русски

Скачайте из Telegram-поста три файла: `plan.wav`, `addon.wav` и
`upgrade.wav`. Ссылка будет добавлена перед публикацией репозитория.

## Install

Clone the repository and pass the directory containing the three WAV files to
the installer:

```sh
git clone https://github.com/aralot/adjutant-sounds.git
cd adjutant-sounds
./install.sh ~/Downloads/adjutant-sounds
```

Restart Codex, open `/hooks`, review the new Stop hook, and trust it.

The installer copies the sounds and the Bash hook script to:

```text
~/.codex/adjutant-sounds/
```

It then adds the `aralot/adjutant-sounds` marketplace and installs the
`adjutant-sounds` plugin.

## Existing sound hook

The installer stops without making changes when it detects the previous manual
sound hook in `~/.codex/hooks.json`.

Remove the old Stop hook that runs `codex-sound.sh` or references
`~/.codex/sounds`, then run the installer again. Other hooks in the same file
can remain.

## Update

Pull the latest changes and run the installer again:

```sh
git pull
./install.sh ~/Downloads/adjutant-sounds
```

Restart Codex after the update. Changed hooks may need to be trusted again in
`/hooks`.

## Uninstall

```sh
codex plugin remove adjutant-sounds@adjutant-sounds
codex plugin marketplace remove adjutant-sounds
rm -rf ~/.codex/adjutant-sounds
```

Restart Codex after uninstalling.

## Troubleshooting

- No sound: check that all three WAV files exist in
  `~/.codex/adjutant-sounds/`.
- Hook failed with code 127: update to version 1.0.2 or newer and rerun the
  installer.
- Hook is not running: open `/hooks` and trust or enable it.
- Two sounds play: remove the old manual Stop hook from
  `~/.codex/hooks.json`.
- Custom sound location: set `ADJUTANT_SOUNDS_DIR` for the Codex process.
- Inspect the selected file without playing it: set
  `ADJUTANT_SOUNDS_DEBUG=1`.

## License and trademarks

The source code is available under the [MIT License](LICENSE).

Audio files are not included and are not covered by the MIT License. This is
an independent fan project and is not affiliated with or endorsed by OpenAI,
Blizzard Entertainment, or the StarCraft franchise. All product names and
trademarks belong to their respective owners.
