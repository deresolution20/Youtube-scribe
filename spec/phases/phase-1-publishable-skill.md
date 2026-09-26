# Phase Spec (Tier 2) — Phase 1: Publishable Skill Packaging

> Deep-plan artifact for ONE vertical slice. The implementation plan (Tier 3 task specs)
> is derived from section 5 via the `writing-plans` skill.

**Parent:** `spec/product-spec.md` → Phase 1
**Depends on phases:** Phase 0 (walking skeleton, done)
**Design approved:** 2026-09-25 (in-session, before writing this spec)

## 1. Goal of this slice

Make `youtube-scribe` a self-contained, MIT-licensed skill that installs from
skills.sh via `npx skills add <owner>/Youtube-scribe`, with the wrapper living
*inside* the skill directory and a separately-installed, version-pinned baoyu engine
treated as an explicit prerequisite.

One sentence of user value: a stranger can install the skill from skills.sh and run
it, with the only manual step being a documented one-line engine install.

## 2. What "done" looks like (phase acceptance criteria)

- [x] `skill/` is renamed to `skills/`; `bin/` is removed; the wrapper lives at
      `skills/youtube-scribe/scripts/yt-transcript` (executable, no repo-relative paths).
- [x] `npx skills add <owner>/Youtube-scribe --list` reports a discoverable
      `youtube-scribe` skill.
- [x] `SKILL.md` frontmatter is valid per the Agent Skills spec: `name`, `description`,
      `license: MIT`, `compatibility`, and `metadata` (`version`, `openclaw.requires.anyBins`).
- [x] `SKILL.md` invokes the wrapper skill-relative (`{baseDir}/scripts/yt-transcript`),
      with no reference to `bin/`, `scripts/install.sh`, or absolute repo paths.
- [x] The wrapper asserts the engine version == `1.1.0`; a missing or mismatched engine
      exits non-zero with the exact `npx skills add ...` command and never auto-installs.
- [x] `README.md` (install, prerequisites, usage, dev) and `LICENSE` (MIT, Brice Neal) exist.
- [x] `scripts/install.sh` symlinks the new skill path and installs the engine only when
      `YT_SCRIBE_INSTALL_ENGINE=1` is set.
- [x] `bats --print-output-on-failure tests/` is green and `shellcheck` is clean on
      `skills/youtube-scribe/scripts/yt-transcript` and `scripts/install.sh`.
- [x] `spec/constitution.md` folder/naming conventions and `spec/product-spec.md`
      phase map + changelog match the new layout.
- [x] Gate: from a clean checkout, `skills add --list` finds the skill and a real run
      produces a timestamp-free `transcript.md` plus a `summary.md`.

## 3. Technical design (the "how")

### 3.1 Repository layout (the move)

```
Youtube-scribe/
├── skills/
│   └── youtube-scribe/
│       ├── SKILL.md                 # canonical skill: frontmatter + workflow
│       └── scripts/
│           └── yt-transcript        # thin wrapper (moved from bin/)
├── command/youtube.md               # opencode-only extra; NOT part of the published skill
├── scripts/install.sh               # local opencode dev installer (symlinks the skill dir)
├── tests/                           # bats suite + fixtures
├── spec/                            # spec-kit artifacts
├── README.md                        # new
├── LICENSE                          # new (MIT)
├── .gitignore  .env.example  CLAUDE.md
```

- `skills/` is a directory the `skills` CLI auto-discovers (as are repo root,
  `.claude/skills/`, `.agents/skills/`, etc.). A flat `skills/<name>/SKILL.md` layout
  is found without `--full-depth`.
- `command/youtube.md` is opencode-specific; it is symlinked by `install.sh` but is not
  referenced by the published skill.

### 3.2 Wrapper (`skills/youtube-scribe/scripts/yt-transcript`)

Stays thin (constitution): locate engine → invoke with `--no-timestamps`, never
`--speakers` → print the transcript path. Changes from the Phase 0 version:

1. **Pinned-version assertion.** Constant `YT_SCRIBE_PINNED_ENGINE_VERSION="1.1.0"`.
   After resolving the engine dir, read `version:` from `$engine_dir/SKILL.md` with
   `grep`/`sed` (no YAML parser) and compare. On mismatch: print the installed vs
   expected version and the pinned install command, exit non-zero. Escape hatch:
   `YT_SCRIBE_ALLOW_ENGINE_VERSION=1` (and a `--allow-engine-version` flag) skips the check.
   This is dependency glue, not transcript metadata logic; the constitution's "no metadata
   logic" rule concerns transcript content.
2. **Discovery hardening.** Only build candidate paths when `HOME` is non-empty (fixes
   probing the filesystem root when `HOME` is unset). Keep the four search dirs plus
   `BAOYU_SKILL_DIR`.
3. **Error fidelity.** Preserve the engine's exit code (`exit "$rc"`) instead of
   collapsing every failure to exit 1, and do not redirect/absorb the engine's stderr
   (it is inherited, so the engine's own error text surfaces). The wrapper's message
   must name the failed stage and include `$rc`, so a blocked/age-restricted video is
   distinguishable from a missing binary.
4. **No repo paths.** The wrapper only knows the engine directory (discovered) and its
   own arguments; it must not reference `bin/`, the repo, or `install.sh`.

New/changed public surface (see section 4).

### 3.3 `SKILL.md`

- Frontmatter (spec fields; `metadata` mirrors the de-facto openclaw convention used by
  baoyu):

```yaml
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
```

- Body: replace the `yt-transcript` / `scripts/install.sh` references with the
  ecosystem convention `{baseDir}` = this skill's directory, e.g.
  `{baseDir}/scripts/yt-transcript '<url>'`, with a fallback to `yt-transcript` on
  `PATH` for the local `install.sh` flow. Add a one-line prerequisite step: if the
  engine is missing, run `npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g`.
- Preserve the existing rules (`--speakers` warning, summary-idempotency wording,
  long-transcript chunking) so `tests/skill-files.bats` keeps passing.

### 3.4 `scripts/install.sh` (local opencode dev only)

- Symlink `skills/youtube-scribe` → `$HOME/.config/opencode/skills/youtube-scribe`
  (whole directory, so `scripts/` travels with it).
- Keep the `$HOME/.local/bin/yt-transcript` symlink (now pointing at
  `skills/youtube-scribe/scripts/yt-transcript`) for manual CLI use; it is a local
  convenience only and is not part of the published skill.
- Symlink `command/youtube.md` → `$HOME/.config/opencode/command/youtube.md`.
- Engine install becomes opt-in: only run the pinned `npx skills add` when
  `YT_SCRIBE_INSTALL_ENGINE=1`; otherwise print the command and continue. No silent
  network installs.

### 3.5 `README.md` / `LICENSE`

- README: what it does; prerequisites (baoyu engine + `bun` or `npx`); install via
  `npx skills add deresolution20/Youtube-scribe` and via `scripts/install.sh`; usage and
  flags; the `{baseDir}` invocation note; dev/test commands; MIT license.
- LICENSE: MIT, `Copyright (c) 2026 Brice Neal`.

### 3.6 Spec maintenance

- `spec/constitution.md` Conventions: naming `wrapper bin/yt-transcript` →
  `skills/youtube-scribe/scripts/yt-transcript`; folder layout `bin/` + `skill/` →
  `skills/youtube-scribe/` (SKILL.md + scripts/) with `command/` retained as an
  opencode-only extra.
- `spec/product-spec.md`: Phase 1 one-liner → "Package as a self-contained, publishable
  skill (skills.sh) with a pinned engine prerequisite"; leave Phase 2 (Whisper) and
  Phase 3 (Beyond v1) unchanged; changelog entry on close.

## 4. Contract / interface with the rest of the system

- **Inputs:** a YouTube URL as the first positional argument; flags `--out-dir DIR`
  (default `./transcripts`), `--languages CODES` (default `en`), `--refresh`,
  `--engine-dir DIR`, `--allow-engine-version`; plus `--print-engine-dir`,
  `--print-runner`, `-h/--help`.
- **Outputs:** the transcript file path as the **last line of stdout** on success;
  human-readable errors on stderr; non-zero exit on failure (engine's exit code preserved
  where possible).
- **Env overrides:** `BAOYU_SKILL_DIR` (engine dir), `YT_SCRIBE_RUNNER` (runner; tests),
  `YT_SCRIBE_ALLOW_ENGINE_VERSION` (skip pin check), `YT_SCRIBE_INSTALL_ENGINE`
  (install.sh opt-in).
- **Public interfaces:** the skill `youtube-scribe` (discovered by the `skills` CLI),
  and the `yt-transcript` CLI above. The `skills add` install is the supported path;
  `scripts/install.sh` is a developer convenience, not part of the published skill.

## 5. Task breakdown (Tier 3 — dependency order)

| # | Task | difficulty | Blocked by | Status |
|---|------|------------|------------|--------|
| 1 | Move layout: `skill/`→`skills/`, wrapper→`skills/youtube-scribe/scripts/`, remove `bin/`, update `.gitignore` | easy | – | todo |
| 2 | Harden wrapper: engine version assertion, `HOME` guard, exit-code/stderr fidelity | hard | 1 | todo |
| 3 | Rewrite `SKILL.md` (frontmatter + `{baseDir}` invocation + prerequisites) | easy | 1 | todo |
| 4 | Rework `scripts/install.sh` (new paths, opt-in engine) + `tests/install.bats` | hard | 1 | todo |
| 5 | Update + expand bats suite (paths, self-containment, pin, frontmatter, `skills add --list`) | hard | 2,3,4 | todo |
| 6 | Add `README.md` + `LICENSE` | easy | 1 | todo |
| 7 | Update `spec/constitution.md` + `spec/product-spec.md` | easy | 1 | todo |
| 8 | Verification gate: clean checkout, `skills add --list`, `skills-ref validate`, real end-to-end run | gate | 5,6,7 | todo |

## 6. Out of scope for this phase

- Enforcing `summary.md` idempotency in code (stays agent/prompt-level).
- CI/lint wiring (no GitHub Action, no Makefile) — noted as a follow-up.
- Whisper fallback (Phase 2) and Beyond-v1 (Phase 3).
- Pushing to GitHub, making the repository public, or creating a skills.sh pack.
- Installing the engine automatically for non-opencode agents.

## 7. Risks / open questions

- **GitHub identity unconfirmed:** README and skill URL assume
  `deresolution20/Youtube-scribe`; confirm the public owner/repo before Step 8.
- **`skills-ref validate` may reject nested `metadata`** (the spec says string values;
  baoyu nests maps). If it fails, flatten `metadata` to string values or drop
  `openclaw` — decide at the gate.
- **Agent portability:** `{baseDir}` is a written convention resolved by the agent, not
  a spec field. Confirm opencode resolves it (baoyu relies on the same convention).
- **`skills add --list` requires network**; tests keep it opt-in (like the existing e2e)
  so the default suite stays offline.

---
_On phase close: check every acceptance criterion, demo the slice, then update the
Product Spec changelog and phase map._
