#!/bin/bash
# install.sh - Set up whisper-dictate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_NAME="ggml-medium.bin"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/${MODEL_NAME}"

echo "=== Whisper Dictate Installer ==="
echo

# 1. Check/install dependencies
echo "Checking dependencies..."

if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is required. Install from https://brew.sh"
    exit 1
fi

if ! command -v sox &>/dev/null; then
    echo "Installing sox..."
    brew install sox
fi

if ! command -v whisper-server &>/dev/null; then
    echo "Installing whisper-cpp..."
    brew install whisper-cpp
fi

if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
    echo "Installing Hammerspoon..."
    brew install --cask hammerspoon
fi

echo "Dependencies OK"
echo

# 2. Download whisper model if needed
WHISPER_PREFIX="$(brew --prefix whisper-cpp)"
MODEL_DIR="${WHISPER_PREFIX}/share/whisper-cpp/models"
MODEL_PATH="${MODEL_DIR}/${MODEL_NAME}"

if [[ ! -f "$MODEL_PATH" ]]; then
    echo "Downloading whisper medium model (~1.5GB)..."
    mkdir -p "$MODEL_DIR"
    curl -L -o "$MODEL_PATH" "$MODEL_URL"
    echo "Model downloaded"
else
    echo "Model already exists: $MODEL_PATH"
fi
echo

# 3. Install whisper-server LaunchAgent
echo "Installing whisper-server LaunchAgent..."
WHISPER_SERVER_PATH="${WHISPER_PREFIX}/bin/whisper-server"
SERVER_PLIST_DEST="$HOME/Library/LaunchAgents/com.whisper-dictate.server.plist"
mkdir -p "$HOME/Library/LaunchAgents"

launchctl unload "$SERVER_PLIST_DEST" 2>/dev/null || true

sed -e "s|{{WHISPER_SERVER_PATH}}|${WHISPER_SERVER_PATH}|g" \
    -e "s|{{MODEL_PATH}}|${MODEL_PATH}|g" \
    "${SCRIPT_DIR}/com.whisper-dictate.server.plist.template" > "$SERVER_PLIST_DEST"

launchctl load "$SERVER_PLIST_DEST"
echo "whisper-server LaunchAgent installed"
echo

# 4. Create data directory
echo "Creating data directory..."
mkdir -p "$HOME/.whisper-dictate"

# 5. Install Hammerspoon config
echo "Installing Hammerspoon configuration..."
HAMMERSPOON_DIR="$HOME/.hammerspoon"
mkdir -p "$HAMMERSPOON_DIR"
cp "${SCRIPT_DIR}/init.lua" "$HAMMERSPOON_DIR/init.lua"
echo "Hammerspoon config installed"
echo

# 6. Done
echo "=== Installation Complete ==="
echo
echo "Next steps:"
echo "1. Open Hammerspoon from Applications (or Spotlight)"
echo "2. Grant Hammerspoon accessibility permissions in System Preferences"
echo "3. Reload Hammerspoon config (click menu bar icon → Reload Config)"
echo "4. Test by holding § and speaking - when prompted, allow microphone access for Hammerspoon"
echo
echo "Note: The first time you use the hotkey, macOS will ask for microphone"
echo "permission. Click 'OK' to allow Hammerspoon to record audio."
