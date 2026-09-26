#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILL_DIR="$REPO/skills/youtube-scribe"
  SKILL="$SKILL_DIR/SKILL.md"
  CLT="$SKILL_DIR/scripts/yt-transcript"
  CMD="$REPO/command/youtube.md"
}

teardown() { unset REPO SKILL_DIR SKILL CLT CMD; }

@test "skill frontmatter has name and description" {
  run grep -E '^name: youtube-scribe$' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^description: .+' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill name matches its directory" {
  [ "$(basename "$SKILL_DIR")" = "youtube-scribe" ]
}

@test "skill frontmatter declares license, compatibility, and metadata" {
  run grep -E '^license: MIT$' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^compatibility: .+' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^  version: "' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill is self-contained and has no repo-relative paths" {
  [ -f "$CLT" ]
  [ -x "$CLT" ]
  run grep -F -- '{baseDir}/scripts/yt-transcript' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -F -- 'bin/yt-transcript' "$SKILL"
  [ "$status" -ne 0 ]
  run grep -F -- 'scripts/install.sh' "$SKILL"
  [ "$status" -ne 0 ]
  run grep -F -- 'bin/yt-transcript' "$CLT"
  [ "$status" -ne 0 ]
  run grep -F -- 'scripts/install.sh' "$CLT"
  [ "$status" -ne 0 ]
}

@test "skill warns against speakers mode" {
  run grep -F -- '--speakers' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "skill protects an existing summary" {
  run grep -F 'already exists' "$SKILL"
  [ "$status" -eq 0 ]
}

@test "command frontmatter is valid" {
  run grep -E '^description: .+' "$CMD"
  [ "$status" -eq 0 ]
}
