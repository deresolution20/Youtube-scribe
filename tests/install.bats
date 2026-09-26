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
  [ -f "$TMP/home/.config/opencode/skills/youtube-scribe/SKILL.md" ]
  [ -f "$TMP/home/.config/opencode/skills/youtube-scribe/scripts/yt-transcript" ]
}

@test "does not install the engine by default" {
  mkdir -p "$TMP/bin"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/npx"
  chmod +x "$TMP/bin/npx"
  HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" run "$REPO/scripts/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping engine install"* ]]
}

@test "engine install is opt-in and calls npx with --yes after skills" {
  mkdir -p "$TMP/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "${NPX_ARGS_FILE}"\nexit 0\n' > "$TMP/bin/npx"
  chmod +x "$TMP/bin/npx"
  NPX_ARGS_FILE="$TMP/npx-args.txt" YT_SCRIBE_INSTALL_ENGINE=1 HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" run "$REPO/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ -f "$TMP/npx-args.txt" ]
  grep -q "^skills$" "$TMP/npx-args.txt"
  grep -q "^add$" "$TMP/npx-args.txt"
  grep -q "^--yes$" "$TMP/npx-args.txt"
  local skills_line yes_line
  skills_line="$(grep -n "^skills$" "$TMP/npx-args.txt" | head -1 | cut -d: -f1)"
  yes_line="$(grep -n "^--yes$" "$TMP/npx-args.txt" | head -1 | cut -d: -f1)"
  [ "$yes_line" -gt "$skills_line" ]
}

@test "fails clearly when HOME is unset" {
  run env -u HOME "$REPO/scripts/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"HOME is not set"* ]]
}
