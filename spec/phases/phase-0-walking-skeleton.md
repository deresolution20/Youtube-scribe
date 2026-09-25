# Phase 0: Walking Skeleton — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent:** `spec/product-spec.md` → Phase 0
**Depends on phases:** none (first phase)

**Goal:** Turn a YouTube URL into a readable, full-sentence transcript file plus a TL;DR file, driven by a thin wrapper over the pinned baoyu engine and exposed through an opencode skill and `/youtube` command.

**Architecture:** A bash wrapper (`bin/yt-transcript`) locates the installed baoyu-youtube-transcript engine, resolves a `bun`/`npx` runner, and invokes it with `--no-timestamps` (never `--speakers`), printing the transcript path. An opencode skill and command call that wrapper, read the transcript, and have the host agent write `summary.md` and echo the TL;DR.

**Tech Stack:** Bash 5; bats-core (tests); shellcheck (lint); the third-party baoyu engine (Bun/TypeScript, consumed unmodified); opencode skill + command markdown.

**Spec:** `spec/product-spec.md`, `spec/constitution.md`

## Global Constraints

- Bash 5; `set -euo pipefail` at the top of every script.
- Never edit or vendor the baoyu engine; it is a pinned dependency behind the wrapper.
- The wrapper stays thin: locate, invoke, print path. No transcript parsing in our code.
- **Always pass `--no-timestamps`; never pass `--speakers`.**
- Single-quote URLs when shelling out (`?` is a zsh glob).
- Local-first: no media upload, no cloud STT. Secrets/config only in `.env` (gitignored).
- Generated output (`transcripts/`) is gitignored.
- Tests must pass: `bats --print-output-on-failure tests/`; lint clean: `shellcheck bin/* scripts/*`.
- Commit steps are intentionally omitted: the user has not authorized commits. Treat each task's end as a checkpoint and ask before committing.

## Review Focus (inputs/failure modes most likely to bite)

1. A URL containing `?`/`&` must reach the engine as one argument, not be glob-split.
2. The engine may be absent or installed in a different skills directory — the wrapper must find it or say exactly how to install it.
3. `bun` may be absent while `npx` is present — the wrapper must still run.
4. Re-running the same URL must reuse the engine cache and must not clobber an existing TL;DR.
5. A video with captions disabled/blocked must fail loudly, not silently produce an empty transcript.

---

### Task 1: Scaffold directories, ignore rules, env template

**Files:**
- Modify: `.gitignore`
- Modify: `.env.example`
- Create: `bin/.gitkeep`, `tests/fixtures/engine/scripts/main.ts`, `tests/fixtures/fake-runner.sh`, `skill/youtube-scribe/`, `command/`, `scripts/`
- difficulty: `easy`

**Interfaces:**
- Consumes: nothing.
- Produces: `transcripts/` ignored; fixture paths used by every bats test; `.env.example` keys.

- [ ] **Step 1: Ignore generated output**

Append to `.gitignore`:

```gitignore

# Generated transcripts
transcripts/
```

- [ ] **Step 2: Document the engine's cookie escape hatch**

Replace `.env.example` with:

```bash
# Copy to .env (gitignored) and fill in. Never commit real values.

# Optional: pass a browser profile to the transcript engine's yt-dlp fallback
# when YouTube blocks anonymous access (e.g. chrome, firefox, safari).
YOUTUBE_TRANSCRIPT_COOKIES_FROM_BROWSER=
```

- [ ] **Step 3: Create the test fixtures**

Create `tests/fixtures/engine/scripts/main.ts` as an empty file (discovery only checks existence):

```bash
mkdir -p tests/fixtures/engine/scripts
: > tests/fixtures/engine/scripts/main.ts
```

Create `tests/fixtures/fake-runner.sh`:

```bash
#!/usr/bin/env bash
# Test double for the transcript engine: prints each argument on its own line,
# then a transcript path, then exits with FAKE_RUNNER_EXIT (default 0).
for arg in "$@"; do printf 'ARG[%s]\n' "$arg"; done
printf '%s\n' "${FAKE_TRANSCRIPT_PATH:-/tmp/fake/transcript.md}"
exit "${FAKE_RUNNER_EXIT:-0}"
```

Then: `chmod +x tests/fixtures/fake-runner.sh && mkdir -p bin skill/youtube-scribe command scripts && touch bin/.gitkeep`

- [ ] **Step 4: Verify the scaffold**

Run: `ls -R bin tests skill command scripts && git status --short`
Expected: directories exist; `.gitignore` and `.env.example` show as modified; no syntax errors.

- [ ] **Step 5: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 2: `bin/yt-transcript` wrapper + bats suite

**Files:**
- Create: `bin/yt-transcript`
- Create: `tests/yt-transcript.bats`
- Test: `tests/yt-transcript.bats`
- difficulty: `hard`

**Interfaces:**
- Consumes: fixtures from Task 1.
- Produces: CLI `yt-transcript <url> [--out-dir DIR] [--languages CODES] [--refresh] [--engine-dir DIR]`, plus `--print-engine-dir` and `--print-runner`. On success it prints the transcript file path on stdout. Honors env `BAOYU_SKILL_DIR` (engine override) and `YT_SCRIBE_RUNNER` (runner override, used by tests).

- [ ] **Step 1: Write the failing tests**

Create `tests/yt-transcript.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bats --print-output-on-failure tests/yt-transcript.bats`
Expected: FAIL — `bin/yt-transcript` does not exist.

- [ ] **Step 3: Implement the wrapper**

Create `bin/yt-transcript`:

```bash
#!/usr/bin/env bash
# Thin wrapper around the baoyu-youtube-transcript engine.
# It (a) locates the pinned engine, (b) always requests a readable transcript
# (--no-timestamps, never --speakers), and (c) prints the output file path.
set -euo pipefail

PROG="yt-transcript"

usage() {
  cat >&2 <<EOF
Usage: $PROG <youtube-url> [options]

Options:
  --out-dir <dir>      Base output directory for transcripts (default: ./transcripts)
  --languages <codes>  Comma-separated language priority list (default: en)
  --refresh            Ignore the engine cache and re-fetch
  --engine-dir <dir>   Explicit baoyu-youtube-transcript skill directory
  --print-engine-dir   Print the resolved engine directory and exit
  --print-runner       Print the command used to run the engine and exit
  -h, --help           Show this help
EOF
}

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }

find_engine_dir() {
  local candidates=() dir
  [ -n "${BAOYU_SKILL_DIR:-}" ] && candidates+=("$BAOYU_SKILL_DIR")
  candidates+=(
    "${HOME:-}/.agents/skills/baoyu-youtube-transcript"
    "${HOME:-}/.claude/skills/baoyu-youtube-transcript"
    "${HOME:-}/.config/opencode/skills/baoyu-youtube-transcript"
    "${HOME:-}/.config/opencode/skill/baoyu-youtube-transcript"
  )
  for dir in "${candidates[@]}"; do
    if [ -n "$dir" ] && [ -f "$dir/scripts/main.ts" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  return 1
}

die_engine_missing() {
  die "baoyu-youtube-transcript engine not found. Install it with:
  npx skills add https://github.com/jimliu/baoyu-skills --skill baoyu-youtube-transcript --agent opencode -g
Then re-run. (Set BAOYU_SKILL_DIR to override the search path.)"
}

resolve_runner() {
  if [ -n "${YT_SCRIBE_RUNNER:-}" ]; then printf '%s\n' "$YT_SCRIBE_RUNNER"; return 0; fi
  if command -v bun >/dev/null 2>&1; then printf '%s\n' "bun"; return 0; fi
  if command -v npx >/dev/null 2>&1; then printf '%s\n' "npx -y bun"; return 0; fi
  return 1
}

print_engine_dir() {
  local dir
  dir="$(find_engine_dir)" || die_engine_missing
  printf '%s\n' "$dir"
}

print_runner() {
  local runner
  runner="$(resolve_runner)" || die "neither 'bun' nor 'npx' is available; install bun: https://bun.sh"
  printf '%s\n' "$runner"
}

run_transcript() {
  local url="$1" out_dir="$2" languages="$3" refresh="$4" engine_dir="$5"
  local runner
  runner="$(resolve_runner)" || die "neither 'bun' nor 'npx' is available; install bun: https://bun.sh"
  local -a runner_cmd
  read -r -a runner_cmd <<<"$runner"
  local -a args=("$engine_dir/scripts/main.ts" "$url" --no-timestamps --output-dir "$out_dir" --languages "$languages")
  [ "$refresh" -eq 1 ] && args+=(--refresh)
  local rc=0
  "${runner_cmd[@]}" "${args[@]}" || rc=$?
  [ "$rc" -eq 0 ] || die "transcript engine failed (exit $rc)"
}

main() {
  local url="" out_dir="transcripts" languages="en" refresh=0 engine_dir=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --print-engine-dir) print_engine_dir; exit 0 ;;
      --print-runner) print_runner; exit 0 ;;
      --out-dir) [ $# -ge 2 ] || die "--out-dir needs a value"; out_dir="$2"; shift 2 ;;
      --languages) [ $# -ge 2 ] || die "--languages needs a value"; languages="$2"; shift 2 ;;
      --engine-dir) [ $# -ge 2 ] || die "--engine-dir needs a value"; engine_dir="$2"; shift 2 ;;
      --refresh) refresh=1; shift ;;
      --) shift; break ;;
      -*) die "unknown option: $1" ;;
      *) [ -z "$url" ] || die "unexpected extra argument: $1"; url="$1"; shift ;;
    esac
  done

  [ -n "$url" ] || { usage; exit 2; }

  if [ -z "$engine_dir" ]; then
    engine_dir="$(find_engine_dir)" || die_engine_missing
  fi
  [ -f "$engine_dir/scripts/main.ts" ] || die "engine dir '$engine_dir' has no scripts/main.ts"

  run_transcript "$url" "$out_dir" "$languages" "$refresh" "$engine_dir"
}

main "$@"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x bin/yt-transcript && bats --print-output-on-failure tests/yt-transcript.bats`
Expected: all 11 tests PASS.

- [ ] **Step 5: Lint**

Run: `shellcheck bin/yt-transcript tests/fixtures/fake-runner.sh`
Expected: no warnings. (If shellcheck flags intentionally-unused vars in the fake runner, add a one-line `# shellcheck disable=SC2034` above it.)

- [ ] **Step 6: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 3: Real end-to-end smoke test (opt-in)

**Files:**
- Create: `tests/e2e.bats`
- difficulty: `gate`

**Interfaces:**
- Consumes: `bin/yt-transcript` (Task 2), real engine installed (via `scripts/install.sh`, Task 6) or `BAOYU_SKILL_DIR`.
- Produces: proof that a real URL yields a readable, timestamp-free transcript.

- [ ] **Step 1: Write the opt-in test**

Create `tests/e2e.bats`:

```bash
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
```

- [ ] **Step 2: Run it (opt-in)**

Prereq: engine installed. Run:
`RUN_NETWORK_TESTS=1 bats --print-output-on-failure tests/e2e.bats`
Expected: PASS — the printed path exists, contains no `-->` and no `[HH:MM:SS]`, and has >50 words.

- [ ] **Step 3: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 4: opencode skill source

**Files:**
- Create: `skill/youtube-scribe/SKILL.md`
- Create: `tests/skill-files.bats`
- Test: `tests/skill-files.bats`
- difficulty: `easy`

**Interfaces:**
- Consumes: `yt-transcript` on `PATH` (installed by Task 6).
- Produces: skill `youtube-scribe` with valid frontmatter and the TLDR workflow.

- [ ] **Step 1: Write the failing test**

Create `tests/skill-files.bats`:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats --print-output-on-failure tests/skill-files.bats`
Expected: FAIL — skill/command files do not exist.

- [ ] **Step 3: Write the skill**

Create `skill/youtube-scribe/SKILL.md`:

```markdown
---
name: youtube-scribe
description: Turn a YouTube URL into a readable full-sentence transcript (no timestamps) plus a TL;DR summary saved beside it. Use when the user provides a YouTube URL or asks to transcribe, summarize, or get a TL;DR of a YouTube video.
---

# YouTube Scribe

Given a YouTube URL, produce a readable transcript and a TL;DR.

## Steps

1. Extract the YouTube URL from the user's request.
2. Run the wrapper, single-quoting the URL (`?` is a shell glob):

   ```
   yt-transcript '<youtube-url>'
   ```

   Useful flags: `--out-dir <dir>` (default `./transcripts`), `--languages en,zh`
   (priority order), `--refresh` (ignore engine cache).
   If `yt-transcript` is not found, tell the user to run `scripts/install.sh`
   from the Youtube-scribe repo, then stop.

3. The command prints the transcript file path (last line of stdout). Read that file.
4. Write `summary.md` in the same directory as the transcript:
   - `# TL;DR` — 3-6 bullets capturing what the video actually says.
   - `## Key points` — the main arguments in order.
   - `## Notable details` — specific facts, numbers, and names worth knowing.
   Base it on the transcript content, **not** the video description.
   If `summary.md` already exists, leave it untouched and say so (do not overwrite).
5. Reply in chat with the TL;DR bullets and both file paths
   (`transcript.md` and `summary.md`). Do not paste the whole transcript unless asked.

## Rules

- Never run the engine's `--speakers` mode; it emits raw per-chunk SRT (a few words per
  timestamp) and is unreadable. The wrapper already avoids it.
- If the transcript is too long for one pass, read it in ranges, summarize each range,
  then combine — do not truncate.
- If the command fails, show the error verbatim and stop.
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bats --print-output-on-failure tests/skill-files.bats`
Expected: all 3 tests PASS.

- [ ] **Step 5: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 5: opencode `/youtube` command source

**Files:**
- Modify: `command/youtube.md`
- difficulty: `easy`

**Interfaces:**
- Consumes: skill `youtube-scribe` (Task 4).
- Produces: `/youtube <url>` entry point.

- [ ] **Step 1: Write the command**

Create `command/youtube.md`:

```markdown
---
description: Transcribe a YouTube video and write a readable transcript plus a TL;DR
---

Transcribe and summarize this YouTube video: $ARGUMENTS

Follow the `youtube-scribe` skill exactly:
1. Run `yt-transcript '$ARGUMENTS'`.
2. Read the transcript file path it prints.
3. Write `summary.md` beside the transcript (TL;DR + key points + notable details),
   unless it already exists.
4. Reply with the TL;DR bullets and both file paths.
```

- [ ] **Step 2: Add the command frontmatter test**

Append to `tests/skill-files.bats`:

```bash

@test "command frontmatter is valid" {
  run grep -E '^description: .+' "$REPO/command/youtube.md"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `bats --print-output-on-failure tests/skill-files.bats`
Expected: all 4 tests PASS.

- [ ] **Step 4: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 6: `scripts/install.sh` + test

**Files:**
- Create: `scripts/install.sh`
- Create: `tests/install.bats`
- Test: `tests/install.bats`
- difficulty: `hard`

**Interfaces:**
- Consumes: `bin/yt-transcript` (Task 2), `skill/youtube-scribe/SKILL.md` (Task 4), `command/youtube.md` (Task 5).
- Produces: `~/.local/bin/yt-transcript` on PATH; `~/.config/opencode/skills/youtube-scribe` and `~/.config/opencode/command/youtube.md` symlinks; baoyu engine installed for opencode. Honors `YT_SCRIBE_SKIP_ENGINE_INSTALL=1` (tests) and `HOME`.

- [ ] **Step 1: Write the failing test**

Create `tests/install.bats`:

```bash
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `bats --print-output-on-failure tests/install.bats`
Expected: FAIL — `scripts/install.sh` does not exist.

- [ ] **Step 3: Implement the installer**

Create `scripts/install.sh`:

```bash
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
    npx -y skills add https://github.com/jimliu/baoyu-skills --skill baoyu-youtube-transcript --agent opencode -g
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x scripts/install.sh && bats --print-output-on-failure tests/install.bats`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `shellcheck scripts/install.sh`
Expected: no warnings.

- [ ] **Step 6: Checkpoint**

Run: `git status --short` (do NOT commit).

---

### Task 7: Phase verification gate (real run)

**Files:**
- None (verification only; update `spec/product-spec.md` phase map + changelog on pass)
- difficulty: `gate`

**Interfaces:**
- Consumes: everything above.
- Produces: a demonstrated end-to-end slice.

- [ ] **Step 1: Install for real**

Run: `scripts/install.sh`
Expected: engine installed, symlinks created. Confirm discovery:
`yt-transcript --print-engine-dir` prints a path ending in `baoyu-youtube-transcript`.

- [ ] **Step 2: Quit and restart opencode**

Required — config/skills are not hot-reloaded. (Ask the user to restart.)

- [ ] **Step 3: Run the slice from a scratch directory**

In a fresh opencode session in a scratch dir, run:
`/youtube https://www.youtube.com/watch?v=aircAruvnKk`

Expected:
- `transcripts/3blue1brown/.../transcript.md` exists and is readable prose: full
  sentences, paragraphs, no `-->`, no `[HH:MM:SS]`.
- `summary.md` exists beside it with a non-empty TL;DR.
- The chat reply shows the TL;DR and both paths.

- [ ] **Step 4: Verify all Phase acceptance criteria**

- [ ] One invocation → transcript file + TL;DR file, no manual steps.
- [ ] Transcript is readable prose (full sentences, no timestamps, no raw fragments).
- [ ] TL;DR reflects content, not the description, and is echoed in chat.
- [ ] Re-running the same URL uses the engine cache and leaves `summary.md` intact.
- [ ] Skill and `/youtube` both work from a fresh session.
- [ ] Only caption/metadata requests left the machine.

- [ ] **Step 5: Close-out**

Update `spec/product-spec.md`: mark Phase 0 `done` in the phase map and add a changelog
entry (with the installed baoyu engine version). Run the full suite:
`bats --print-output-on-failure tests/ && shellcheck bin/yt-transcript scripts/install.sh`
Expected: green. Then ask the user whether to commit.
