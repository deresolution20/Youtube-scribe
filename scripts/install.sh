#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -n "${HOME:-}" ] || { echo "install.sh: HOME is not set" >&2; exit 1; }
SKILL_DIR="$REPO/skills/youtube-scribe"
WRAPPER="$SKILL_DIR/scripts/yt-transcript"
ENGINE_INSTALL_CMD="npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g"

chmod +x "$WRAPPER"
mkdir -p "$HOME/.local/bin" "$HOME/.config/opencode/skills" "$HOME/.config/opencode/command"

ln -sfn "$WRAPPER" "$HOME/.local/bin/yt-transcript"
ln -sfn "$SKILL_DIR" "$HOME/.config/opencode/skills/youtube-scribe"
ln -sfn "$REPO/command/youtube.md" "$HOME/.config/opencode/command/youtube.md"

if [ "${YT_SCRIBE_SKIP_ENGINE_INSTALL:-0}" = "1" ]; then
  :
elif [ "${YT_SCRIBE_INSTALL_ENGINE:-0}" = "1" ]; then
  if command -v npx >/dev/null 2>&1; then
    echo "Installing baoyu-youtube-transcript engine..."
    npx -y skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g --yes
  else
    echo "install.sh: npx not found; install Node.js, or install the engine manually." >&2
  fi
else
  echo "Skipping engine install. Install it separately with:"
  echo "  $ENGINE_INSTALL_CMD"
  echo "(or re-run with YT_SCRIBE_INSTALL_ENGINE=1)"
fi

echo
echo "Installed:"
echo "  wrapper -> $HOME/.local/bin/yt-transcript"
echo "  skill   -> $HOME/.config/opencode/skills/youtube-scribe"
echo "  command -> $HOME/.config/opencode/command/youtube.md"
echo
echo "Quit and restart opencode for the new skill and command to load."
