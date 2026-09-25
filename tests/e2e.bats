#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CLT="$REPO/bin/yt-transcript"
  TMP="$(mktemp -d)"
}

teardown() { rm -rf "$TMP"; }

@test "real end-to-end: transcript is readable and timestamp-free" {
  [ "${RUN_NETWORK_TESTS:-0}" = "1" ] || skip "set RUN_NETWORK_TESTS=1 to run network tests"
  run "$CLT" 'https://www.youtube.com/watch?v=aircAruvnKk' --out-dir "$TMP/out"
  [ "$status" -eq 0 ]
  local path
  path="$(printf '%s\n' "$output" | tail -n1)"
  [ -f "$path" ]
  ! grep -q -- '-->' "$path"
  ! grep -qE '\[[0-9]{2}:[0-9]{2}:[0-9]{2}' "$path"
  [ "$(wc -w < "$path")" -gt 50 ]
}
