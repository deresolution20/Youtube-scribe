#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/.local/bin" "$HOME/.config/opencode/skills" "$HOME/.config/opencode/command"

chmod +x "$REPO/bin/yt-transcript"
ln -sfn "$REPO/bin/yt-transcript" "$HOME/.local/bin/yt-transcript"
ln -sfn "$REPO/skill/youtube-scribe" "$HOME/.config/opencode/skills/youtube-scribe"
ln -sfn "$REPO/command/youtube.md" "$HOME/.config/opencode/command/youtube.md"

if [ "${YT_SCRIBE_SKIP_ENGINE_INSTALL:-0}" != "1" ]; then
  if command -v npx >/dev/null 2>&1; then
    echo "Installing baoyu-youtube-transcript engine for opencode..."
    npx -y skills add https://github.com/jimliu/baoyu-skills --skill baoyu-youtube-transcript --agent opencode -g --yes
  else
    echo "install.sh: npx not found; install Node.js, or install the engine manually." >&2
  fi
fi

echo
echo "Installed:"
echo "  wrapper -> $HOME/.local/bin/yt-transcript"
echo "  skill   -> $HOME/.config/opencode/skills/youtube-scribe"
echo "  command -> $HOME/.config/opencode/command/youtube.md"
echo
echo "Quit and restart opencode for the new skill and command to load."
