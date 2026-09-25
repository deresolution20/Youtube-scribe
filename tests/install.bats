#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
}

teardown() { rm -rf "$TMP"; }

@test "installs wrapper, skill, and command symlinks" {
  YT_SCRIBE_SKIP_ENGINE_INSTALL=1 HOME="$TMP/home" run "$REPO/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ -L "$TMP/home/.local/bin/yt-transcript" ]
  [ -L "$TMP/home/.config/opencode/skills/youtube-scribe" ]
  [ -L "$TMP/home/.config/opencode/command/youtube.md" ]
  [ -x "$TMP/home/.local/bin/yt-transcript" ]
}
