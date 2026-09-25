#!/usr/bin/env bats

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"; }

@test "skill frontmatter is valid" {
  run grep -E '^name: youtube-scribe$' "$REPO/skill/youtube-scribe/SKILL.md"
  [ "$status" -eq 0 ]
  run grep -E '^description: .+' "$REPO/skill/youtube-scribe/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill warns against speakers mode" {
  run grep -F -- '--speakers' "$REPO/skill/youtube-scribe/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skill protects an existing summary" {
  run grep -F 'already exists' "$REPO/skill/youtube-scribe/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "command frontmatter is valid" {
  run grep -E '^description: .+' "$REPO/command/youtube.md"
  [ "$status" -eq 0 ]
}
