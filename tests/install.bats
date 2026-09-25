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

@test "engine install calls npx with --yes" {
  mkdir -p "$TMP/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "${NPX_ARGS_FILE}"\nexit 0\n' > "$TMP/bin/npx"
  chmod +x "$TMP/bin/npx"
  NPX_ARGS_FILE="$TMP/npx-args.txt" HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" run "$REPO/scripts/install.sh"
  [ "$status" -eq 0 ]
  [ -f "$TMP/npx-args.txt" ]
  local args
  args="$(cat "$TMP/npx-args.txt")"
  echo "DEBUG args: $args"
  echo "$args" | grep -q "skills" || { echo "FAIL: no 'skills' in args"; cat "$TMP/npx-args.txt"; return 1; }
  echo "$args" | grep -q "add" || { echo "FAIL: no 'add' in args"; cat "$TMP/npx-args.txt"; return 1; }
  echo "$args" | grep -q "\-\-yes" || { echo "FAIL: no '--yes' in args"; cat "$TMP/npx-args.txt"; return 1; }
}
