# Whisper Dictate

Push-to-talk dictation for macOS using [whisper.cpp](https://github.com/ggerganov/whisper.cpp) and [Hammerspoon](https://www.hammerspoon.org/).

Hold the `§` key to record, release to transcribe and paste.

## Requirements

- macOS
- [Homebrew](https://brew.sh)

## Installation

```bash
./install.sh
```

This will:
1. Install dependencies (sox, whisper-cpp, Hammerspoon)
2. Download the Whisper medium model (~1.5GB)
3. Install and start a local whisper-server that runs in the background (via launchd)
4. Install the Hammerspoon configuration

After installation:
1. Grant Hammerspoon accessibility permissions in System Preferences
2. Reload Hammerspoon config

## Usage

- Hold `§` to record
- Release `§` to transcribe and paste
- `Option+§` to press Enter
- `Ctrl+§` to cycle language: auto → English → Dutch

## Configuration

The whisper-server runs on `127.0.0.1:9876` and logs to `/tmp/whisper-server.log`.

Debug logs are written to `~/.whisper-dictate/whisper-dictate.log`.

## License

MIT
