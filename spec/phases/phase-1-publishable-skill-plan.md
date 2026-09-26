# Phase 1: Publishable Skill Packaging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `youtube-scribe` a self-contained, MIT-licensed skill installable via `npx skills add <owner>/Youtube-scribe`, depending on a separately-installed, version-pinned baoyu engine.

**Architecture:** The wrapper moves from `bin/` into the skill directory (`skills/youtube-scribe/scripts/yt-transcript`) so the skill travels as one unit. The wrapper gains a runtime engine-version assertion and drops all repo-relative paths. `scripts/install.sh` remains an opencode developer convenience. Docs (`README.md`, `LICENSE`) and spec conventions are updated. No cross-skill dependency exists in the Agent Skills spec, so the engine is an explicit prerequisite, never auto-installed.

**Tech Stack:** Bash 5; bats-core; shellcheck; Agent Skills (`SKILL.md`) format; the `skills` CLI (vercel-labs/skills); third-party baoyu-youtube-transcript engine (Bun/TypeScript, unmodified, pinned v1.1.0).

**Spec:** `spec/phases/phase-1-publishable-skill.md`, `spec/constitution.md`

## Global Constraints

- Bash 5; `set -euo pipefail` at the top of every script.
- Never edit or vendor the baoyu engine; treat it as a pinned dependency behind the wrapper.
- The wrapper stays thin: locate engine, invoke, print path. No transcript parsing.
- Always pass `--no-timestamps`; never pass `--speakers`.
- Single-quote URLs when shelling out (`?` is a zsh glob).
- Skill `name` must match its parent directory name; lowercase + hyphens only.
- `license: MIT`; `compatibility` ≤ 500 chars; `description` ≤ 1024 chars.
- Tests: `bats --print-output-on-failure tests/`; lint: `shellcheck`.
- No commits without explicit user authorization (branch created on request; checkpoints only).

## Review Focus

1. A missing or wrong-version engine must fail loudly with the install command, never silently run an unpinned engine or auto-install.
2. A URL containing `?`/`&` must still reach the engine as one argument.
3. `{baseDir}` may be unresolvable by some agents; a `PATH` fallback must still let the wrapper run.
4. Engine non-zero exits must preserve the engine's exit code, not collapse to 1.
5. `install.sh` must never perform a network install unless `YT_SCRIBE_INSTALL_ENGINE=1`.

---

### Task 1: Move layout (`skill/`→`skills/`, wrapper into the skill)

**Files:**
- Move: `skill/youtube-scribe/SKILL.md` → `skills/youtube-scribe/SKILL.md`
- Move: `bin/yt-transcript` → `skills/youtube-scribe/scripts/yt-transcript`
- Remove: `bin/.gitkeep`, `bin/`, `skill/`
- Modify: `.gitignore`
- Test: `git status --short`

- [ ] **Step 1: Move files with git**

```bash
mkdir -p skills/youtube-scribe/scripts
git mv skill/youtube-scribe/SKILL.md skills/youtube-scribe/SKILL.md
git mv bin/yt-transcript skills/youtube-scribe/scripts/yt-transcript
git rm -q bin/.gitkeep
rmdir skill/youtube-scribe skill bin 2>/dev/null || true
```

- [ ] **Step 2: Ignore the scratch note**

Append to `.gitignore`:

```gitignore

# Personal scratch notes
action-notes.md
```

- [ ] **Step 3: Verify**

Run: `git status --short && ls -R skills`
Expected: renames recorded, `skills/youtube-scribe/{SKILL.md,scripts/yt-transcript}`, `bin/` gone.

---

### Task 2: Harden the wrapper (pin assertion, HOME guard, exit fidelity)

**Files:**
- Modify: `skills/youtube-scribe/scripts/yt-transcript`
- Test: `tests/yt-transcript.bats`

**Interfaces:**
- Produces: CLI `yt-transcript <url> [--out-dir DIR] [--languages CODES] [--refresh] [--engine-dir DIR] [--allow-engine-version]` plus `--print-engine-dir`, `--print-runner`, `-h`.
- Env: `BAOYU_SKILL_DIR`, `YT_SCRIBE_RUNNER`, `YT_SCRIBE_ALLOW_ENGINE_VERSION`.
- Constant: `PINNED_ENGINE_VERSION="1.1.0"`.

- [ ] **Step 1: Update the test fixtures for version checking**

In `tests/yt-transcript.bats`, update `stub_engine` to write a `SKILL.md` and change `CLT`:

```bash
CLT="$REPO/skills/youtube-scribe/scripts/yt-transcript"

stub_engine() {
  mkdir -p "$TMP/engine/scripts"
  : > "$TMP/engine/scripts/main.ts"
  printf 'name: baoyu-youtube-transcript\nversion: 1.1.0\n' > "$TMP/engine/SKILL.md"
  export BAOYU_SKILL_DIR="$TMP/engine"
}
```

- [ ] **Step 2: Add failing pin tests**

Append to `tests/yt-transcript.bats`:

```bash
@test "rejects an engine with a different version" {
  mkdir -p "$TMP/engine/scripts"
  : > "$TMP/engine/scripts/main.ts"
  printf 'name: baoyu-youtube-transcript\nversion: 9.9.9\n' > "$TMP/engine/SKILL.md"
  export BAOYU_SKILL_DIR="$TMP/engine" YT_SCRIBE_RUNNER="$FAKE_RUNNER"
  run "$CLT" 'https://youtu.be/abc'
  [ "$status" -ne 0 ]
  [[ "$output" == *"version mismatch"* ]]
  [[ "$output" != *"ARG["* ]]
}

@test "--allow-engine-version bypasses the pin check" {
  mkdir -p "$TMP/engine/scripts"
  : > "$TMP/engine/scripts/main.ts"
  printf 'name: baoyu-youtube-transcript\nversion: 9.9.9\n' > "$TMP/engine/SKILL.md"
  export BAOYU_SKILL_DIR="$TMP/engine" YT_SCRIBE_RUNNER="$FAKE_RUNNER"
  run "$CLT" 'https://youtu.be/abc' --allow-engine-version
  [ "$status" -eq 0 ]
  [[ "$output" == *"ARG[--no-timestamps]"* ]]
}

@test "preserves the engine exit code" {
  stub_engine
  export YT_SCRIBE_RUNNER="$FAKE_RUNNER" FAKE_RUNNER_EXIT=7
  run "$CLT" 'https://youtu.be/abc'
  [ "$status" -eq 7 ]
}
```

- [ ] **Step 3: Run to verify failures**

Run: `bats --print-output-on-failure tests/yt-transcript.bats`
Expected: new tests FAIL (no pin logic; `CLT` path exists after Task 1 but behavior missing).

- [ ] **Step 4: Implement the wrapper**

Replace `skills/youtube-scribe/scripts/yt-transcript` with:

```bash
#!/usr/bin/env bash
# Thin wrapper around the baoyu-youtube-transcript engine.
# It (a) locates the pinned engine and checks its version, (b) always requests a
# readable transcript (--no-timestamps, never --speakers), and (c) prints the
# output file path.
set -euo pipefail

PROG="yt-transcript"
ENGINE_NAME="baoyu-youtube-transcript"
PINNED_ENGINE_VERSION="1.1.0"
ENGINE_INSTALL_CMD="npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g"

usage() {
  cat >&2 <<EOF
Usage: $PROG <youtube-url> [options]

Options:
  --out-dir <dir>          Base output directory for transcripts (default: ./transcripts)
  --languages <codes>      Comma-separated language priority list (default: en)
  --refresh                Ignore the engine cache and re-fetch
  --engine-dir <dir>       Explicit $ENGINE_NAME skill directory
  --allow-engine-version   Skip the pinned engine version check
  --print-engine-dir       Print the resolved engine directory and exit
  --print-runner           Print the command used to run the engine and exit
  -h, --help               Show this help

Environment:
  BAOYU_SKILL_DIR                    Override the engine directory
  YT_SCRIBE_RUNNER                   Override the bun/npx runner
  YT_SCRIBE_ALLOW_ENGINE_VERSION=1   Skip the pinned engine version check
EOF
}

die() { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }

find_engine_dir() {
  local candidates=() dir
  [ -n "${BAOYU_SKILL_DIR:-}" ] && candidates+=("$BAOYU_SKILL_DIR")
  if [ -n "${HOME:-}" ]; then
    candidates+=(
      "$HOME/.agents/skills/$ENGINE_NAME"
      "$HOME/.claude/skills/$ENGINE_NAME"
      "$HOME/.config/opencode/skills/$ENGINE_NAME"
      "$HOME/.config/opencode/skill/$ENGINE_NAME"
    )
  fi
  for dir in "${candidates[@]}"; do
    if [ -f "$dir/scripts/main.ts" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done
  return 1
}

resolve_runner() {
  if [ -n "${YT_SCRIBE_RUNNER:-}" ]; then printf '%s\n' "$YT_SCRIBE_RUNNER"; return 0; fi
  if command -v bun >/dev/null 2>&1; then printf '%s\n' "bun"; return 0; fi
  if command -v npx >/dev/null 2>&1; then printf '%s\n' "npx -y bun"; return 0; fi
  return 1
}

die_engine_missing() {
  die "$ENGINE_NAME engine not found. Install it with:
  $ENGINE_INSTALL_CMD
Then re-run. (Set BAOYU_SKILL_DIR to override the search path.)"
}

engine_version() {
  local dir="$1" version
  [ -f "$dir/SKILL.md" ] || return 1
  version="$(grep -m1 -E '^version:' "$dir/SKILL.md" | sed -E 's/^version:[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$version" ] || return 1
  printf '%s\n' "$version"
}

assert_engine_version() {
  local dir="$1" allow="$2" version
  if [ "$allow" -eq 1 ]; then return 0; fi
  version="$(engine_version "$dir")" || version=""
  if [ "$version" != "$PINNED_ENGINE_VERSION" ]; then
    die "engine version mismatch: expected $PINNED_ENGINE_VERSION, found ${version:-unknown}.
Update the engine with:
  $ENGINE_INSTALL_CMD
Or pass --allow-engine-version / set YT_SCRIBE_ALLOW_ENGINE_VERSION=1 to skip this check."
  fi
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
  local url="$1" out_dir="$2" languages="$3" refresh="$4" engine_dir="$5" allow="$6"
  assert_engine_version "$engine_dir" "$allow"
  local runner
  runner="$(resolve_runner)" || die "neither 'bun' nor 'npx' is available; install bun: https://bun.sh"
  local -a args=("$engine_dir/scripts/main.ts" "$url" --no-timestamps --output-dir "$out_dir" --languages "$languages")
  [ "$refresh" -eq 1 ] && args+=(--refresh)
  local rc=0
  if [[ "$runner" == */* ]]; then
    "$runner" "${args[@]}" || rc=$?
  else
    local -a runner_cmd
    read -r -a runner_cmd <<<"$runner"
    "${runner_cmd[@]}" "${args[@]}" || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    printf '%s: transcript engine failed (exit %s)\n' "$PROG" "$rc" >&2
    exit "$rc"
  fi
}

main() {
  local url="" out_dir="transcripts" languages="en" refresh=0 engine_dir=""
  local allow_version=0
  [ "${YT_SCRIBE_ALLOW_ENGINE_VERSION:-0}" = "1" ] && allow_version=1

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --print-engine-dir) print_engine_dir; exit 0 ;;
      --print-runner) print_runner; exit 0 ;;
      --out-dir) [ $# -ge 2 ] || die "--out-dir needs a value"; out_dir="$2"; shift 2 ;;
      --languages) [ $# -ge 2 ] || die "--languages needs a value"; languages="$2"; shift 2 ;;
      --engine-dir) [ $# -ge 2 ] || die "--engine-dir needs a value"; engine_dir="$2"; shift 2 ;;
      --refresh) refresh=1; shift ;;
      --allow-engine-version) allow_version=1; shift ;;
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

  run_transcript "$url" "$out_dir" "$languages" "$refresh" "$engine_dir" "$allow_version"
}

main "$@"
```

- [ ] **Step 5: Make executable, run tests, lint**

Run: `chmod +x skills/youtube-scribe/scripts/yt-transcript && bats --print-output-on-failure tests/yt-transcript.bats && shellcheck skills/youtube-scribe/scripts/yt-transcript`
Expected: all PASS, shellcheck clean.

---

### Task 3: Rewrite `SKILL.md`

**Files:**
- Modify: `skills/youtube-scribe/SKILL.md`
- Test: `tests/skill-files.bats`

**Interfaces:**
- Consumes: `scripts/yt-transcript` (Task 2).
- Produces: skill `youtube-scribe` with valid spec frontmatter and a `{baseDir}` invocation.

- [ ] **Step 1: Write the new SKILL.md**

```markdown
---
name: youtube-scribe
description: Turn a YouTube URL into a readable full-sentence transcript (no timestamps) plus a TL;DR summary saved beside it. Use when the user provides a YouTube URL or asks to transcribe, summarize, or get a TL;DR of a YouTube video.
license: MIT
compatibility: Requires the baoyu-youtube-transcript skill (install separately) and bun or npx.
metadata:
  version: "1.0.0"
  openclaw:
    requires:
      anyBins:
        - bun
        - npx
---

# YouTube Scribe

Given a YouTube URL, produce a readable transcript and a TL;DR.

This skill's directory is referred to as `{baseDir}`. It contains
`scripts/yt-transcript`, a thin wrapper around the separate
**baoyu-youtube-transcript** engine.

## Prerequisites

The engine is a separate skill and is not bundled. If it is missing, the wrapper
prints the install command and stops. Install it once with:

```
npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g
```

`bun` (preferred) or `npx` is required to run the engine.

## Steps

1. Extract the YouTube URL from the user's request.
2. Run the wrapper from this skill's directory, single-quoting the URL
   (`?` is a shell glob):

   ```
   {baseDir}/scripts/yt-transcript '<youtube-url>'
   ```

   If `{baseDir}` cannot be resolved but `yt-transcript` is on `PATH`, that works too.

   Useful flags: `--out-dir <dir>` (default `./transcripts`), `--languages en,zh`
   (priority order), `--refresh` (ignore engine cache).
   If the engine is missing, show the install command the wrapper prints and stop.
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

- [ ] **Step 2: Update `tests/skill-files.bats`**

Replace with tests covering paths, frontmatter, self-containment, and wrapper presence:

```bash
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
```

- [ ] **Step 3: Run tests**

Run: `bats --print-output-on-failure tests/skill-files.bats`
Expected: all PASS.

---

### Task 4: Rework `scripts/install.sh` and `tests/install.bats`

**Files:**
- Modify: `scripts/install.sh`
- Modify: `tests/install.bats`
- Test: `tests/install.bats`

**Interfaces:**
- Consumes: `skills/youtube-scribe/` (Tasks 1–3), `command/youtube.md`.
- Produces: symlinks `~/.local/bin/yt-transcript`,
  `~/.config/opencode/skills/youtube-scribe`, `~/.config/opencode/command/youtube.md`;
  engine install only when `YT_SCRIBE_INSTALL_ENGINE=1`.

- [ ] **Step 1: Write the new test**

Replace `tests/install.bats`:

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
```

- [ ] **Step 2: Run to verify failures**

Run: `bats --print-output-on-failure tests/install.bats`
Expected: FAIL (installer still uses old paths / unconditional engine install).

- [ ] **Step 3: Implement the installer**

Replace `scripts/install.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
    echo "Installing $ENGINE_NAME engine..."
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
```

`ENGINE_NAME` is not set in install.sh; replace the echo with a literal
`Installing baoyu-youtube-transcript engine...`.

- [ ] **Step 4: Run tests and lint**

Run: `chmod +x scripts/install.sh && bats --print-output-on-failure tests/install.bats && shellcheck scripts/install.sh`
Expected: all PASS, shellcheck clean.

---

### Task 5: Finish the suite (e2e path, version fixture, opt-in discovery)

**Files:**
- Modify: `tests/e2e.bats`
- Test: `bats --print-output-on-failure tests/`

- [ ] **Step 1: Repoint e2e and add an opt-in discovery check**

In `tests/e2e.bats`, set `CLT="$REPO/skills/youtube-scribe/scripts/yt-transcript"` and append:

```bash
@test "skills CLI discovers youtube-scribe (opt-in)" {
  [ "${RUN_NETWORK_TESTS:-0}" = "1" ] || skip "set RUN_NETWORK_TESTS=1 to run network tests"
  run npx -y skills add "$REPO" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"youtube-scribe"* ]]
}
```

- [ ] **Step 2: Run the full suite**

Run: `bats --print-output-on-failure tests/`
Expected: all PASS (network tests skipped by default).

- [ ] **Step 3: Lint all shell**

Run: `shellcheck skills/youtube-scribe/scripts/yt-transcript scripts/install.sh tests/fixtures/fake-runner.sh`
Expected: clean.

---

### Task 6: Add `README.md` and `LICENSE`

**Files:**
- Create: `README.md`
- Create: `LICENSE`

- [ ] **Step 1: Write `LICENSE`**

Standard MIT text with `Copyright (c) 2026 Brice Neal`.

- [ ] **Step 2: Write `README.md`**

Sections: what it does; prerequisites (baoyu engine + `bun`/`npx`); install via
`npx skills add deresolution20/Youtube-scribe`; local opencode install via
`scripts/install.sh`; usage + flags; `{baseDir}` note; dev/test commands; MIT license.

- [ ] **Step 3: Verify**

Run: `head -1 LICENSE && grep -F -e 'skills add' -e 'Prerequisites' README.md`
Expected: `MIT License` and both strings present.

---

### Task 7: Update constitution and product spec

**Files:**
- Modify: `spec/constitution.md`
- Modify: `spec/product-spec.md`
- Test: `git diff --stat`

- [ ] **Step 1: Update conventions**

In `spec/constitution.md` Conventions: wrapper path
`bin/yt-transcript` → `skills/youtube-scribe/scripts/yt-transcript`; folder layout
`bin/` + `skill/` → `skills/youtube-scribe/` (SKILL.md + scripts/), `command/` retained
as an opencode-only extra.

- [ ] **Step 2: Update the phase map and changelog**

In `spec/product-spec.md`: set Phase 1's one-liner to
"Package as a self-contained, publishable skill (skills.sh) with a pinned engine
prerequisite" with status `active`; append a changelog entry dated 2026-09-25.

- [ ] **Step 3: Verify**

Run: `git diff --stat && grep -n "skills/youtube-scribe" spec/constitution.md`
Expected: both files changed; wrapper path updated.

---

### Task 8: Verification gate

**Files:**
- None (verification only)

- [ ] **Step 1: Full offline suite + lint**

Run: `bats --print-output-on-failure tests/ && shellcheck skills/youtube-scribe/scripts/yt-transcript scripts/install.sh`
Expected: green.

- [ ] **Step 2: Validate the skill format**

Run: `npx -y skills-ref validate skills/youtube-scribe` (if available)
Expected: frontmatter valid. If the tool rejects nested `metadata`, flatten `metadata`
to string values and re-run.

- [ ] **Step 3: Opt-in discovery + real run**

Run: `RUN_NETWORK_TESTS=1 bats --print-output-on-failure tests/e2e.bats`
Expected: discovery finds `youtube-scribe`; real URL yields a timestamp-free
`transcript.md`. (Requires the pinned engine installed and network.)

- [ ] **Step 4: Confirm acceptance criteria and report**

Walk `spec/phases/phase-1-publishable-skill.md` §2 checkboxes; then hand to
`@code-reviewer`.

---

## Self-Review

- **Spec coverage:** layout move (T1), pin + HOME guard + exit fidelity (T2), SKILL.md
  frontmatter + `{baseDir}` (T3), opt-in engine install (T4), tests incl. self-containment
  (T3/T5), README/LICENSE (T6), spec/constitution (T7), gate (T8). No gaps.
- **Placeholders:** none; all code and tests are literal. (`ENGINE_NAME` note in T4 is
  an explicit correction, not a TBD.)
- **Type consistency:** `PINNED_ENGINE_VERSION`, `ENGINE_NAME`, `ENGINE_INSTALL_CMD`,
  env var names, and the `--allow-engine-version` flag are used identically across tasks.
- **Review Focus:** each of the five items is pinned by a test (T2 pin/mismatch/allow/exit,
  T1+T2 URL-as-one-arg, T3 PATH fallback wording, T4 no-network-default).
