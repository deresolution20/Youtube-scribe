#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CLT="$REPO/bin/yt-transcript"
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  unset BAOYU_SKILL_DIR YT_SCRIBE_RUNNER
  export FAKE_RUNNER="$REPO/tests/fixtures/fake-runner.sh"
}

teardown() { rm -rf "$TMP"; }

stub_engine() {
  mkdir -p "$TMP/engine/scripts"
  : > "$TMP/engine/scripts/main.ts"
  export BAOYU_SKILL_DIR="$TMP/engine"
}

@test "resolves engine dir from BAOYU_SKILL_DIR" {
  stub_engine
  run "$CLT" --print-engine-dir
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP/engine" ]
}

@test "discovers engine under ~/.agents/skills" {
  mkdir -p "$HOME/.agents/skills/baoyu-youtube-transcript/scripts"
  : > "$HOME/.agents/skills/baoyu-youtube-transcript/scripts/main.ts"
  run "$CLT" --print-engine-dir
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/.agents/skills/baoyu-youtube-transcript" ]
}

@test "prints install guidance when engine is missing" {
  run "$CLT" --print-engine-dir
  [ "$status" -ne 0 ]
  [[ "$output" == *"npx skills add"* ]]
}

@test "prefers YT_SCRIBE_RUNNER override" {
  export YT_SCRIBE_RUNNER="/custom/runner"
  run "$CLT" --print-runner
  [ "$status" -eq 0 ]
  [ "$output" = "/custom/runner" ]
}

@test "falls back to npx when bun is absent" {
  mkdir -p "$TMP/bin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/npx"
  chmod +x "$TMP/bin/npx"
  PATH="$TMP/bin:/usr/bin:/bin" run "$CLT" --print-runner
  [ "$status" -eq 0 ]
  [ "$output" = "npx -y bun" ]
}

@test "executes compound runner: npx -y bun receives correct args" {
  stub_engine
  mkdir -p "$TMP/bin"
  printf '#!/usr/bin/env bash\nfor arg in "$@"; do printf "ARG[%%s]\\n" "$arg"; done\nprintf "%%s\\n" "${FAKE_TRANSCRIPT_PATH:-/tmp/fake/transcript.md}"\nexit 0\n' > "$TMP/bin/npx"
  chmod +x "$TMP/bin/npx"
  export PATH="$TMP/bin:/usr/bin:/bin"
  run "$CLT" 'https://youtu.be/xyz'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG[-y]"* ]]
  [[ "$output" == *"ARG[bun]"* ]]
  [[ "$output" == *"ARG[$TMP/engine/scripts/main.ts]"* ]]
  [[ "$output" == *"ARG[--no-timestamps]"* ]]
  [[ "$output" == *"ARG[https://youtu.be/xyz]"* ]]
  [[ "$output" != *"--speakers"* ]]
}

@test "passes URL as one argument (question mark and ampersand intact)" {
  stub_engine
  export YT_SCRIBE_RUNNER="$FAKE_RUNNER"
  run "$CLT" 'https://www.youtube.com/watch?v=abc123&t=42'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG[https://www.youtube.com/watch?v=abc123&t=42]"* ]]
}

@test "requests readable output: --no-timestamps, never --speakers" {
  stub_engine
  export YT_SCRIBE_RUNNER="$FAKE_RUNNER"
  run "$CLT" 'https://youtu.be/abc'
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG[--no-timestamps]"* ]]
  [[ "$output" != *"--speakers"* ]]
}

@test "forwards --out-dir and --languages" {
  stub_engine
  export YT_SCRIBE_RUNNER="$FAKE_RUNNER"
  run "$CLT" 'https://youtu.be/abc' --out-dir "$TMP/out" --languages en,zh
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG[$TMP/out]"* ]]
  [[ "$output" == *"ARG[en,zh]"* ]]
}

@test "fails on unknown option" {
  run "$CLT" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "fails with usage when no URL is given" {
  run "$CLT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "propagates engine failure" {
  stub_engine
  export YT_SCRIBE_RUNNER="$FAKE_RUNNER" FAKE_RUNNER_EXIT=3
  run "$CLT" 'https://youtu.be/abc'
  [ "$status" -ne 0 ]
  [[ "$output" == *"transcript engine failed"* ]]
}
