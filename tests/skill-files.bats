#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SKILL="$REPO/skill/youtube-scribe/SKILL.md"
  CMD="$REPO/command/youtube.md"
}

teardown() { unset REPO SKILL CMD; }

@test "skill frontmatter is valid" {
  run grep -E '^name: youtube-scribe$' "$SKILL"
  [ "$status" -eq 0 ]
  run grep -E '^description: .+' "$SKILL"
  [ "$status" -eq 0 ]
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
