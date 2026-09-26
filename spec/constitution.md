# Constitution — Youtube-scribe

> Immutable project principles the agents must obey in **every** session and **every**
> task. Keep it short — it is prepended to agent context often, so bloat here causes
> context rot. (Ref: Spec Kit /speckit.constitution)

## Stack & tooling
- Language / runtime: **Bash 5** (our wrapper + glue); **Bun/TypeScript** runs the
  third-party transcript engine (baoyu) which we consume as a dependency, not our code.
- Framework(s): none. A local CLI plus two opencode entry points (a skill and a command).
- Package manager / build: none for our code. The engine is installed with
  `npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g`; it
  executes with `bun`.
- Test runner: **bats** (`bats --print-output-on-failure tests/`).
- Lint / format: **shellcheck** for all shell files; `bash -n` as a fast syntax gate.

## Non-negotiable rules
- [ ] Every task ships with tests; a task is not "done" until tests pass.
- [ ] No task may touch files outside the ones listed in its Task Spec.
- [ ] Update the Product Spec when a phase closes (fight spec-code drift).
- [ ] Secrets live in `.env` (gitignored), never in code or specs.
- [ ] **Never edit or vendor the third-party baoyu engine.** Treat it as a pinned
      dependency behind our wrapper. Record its installed version in the changelog.
- [ ] The wrapper stays thin: it locates the engine, invokes it, and prints its output
      path. No transcript parsing, de-duplication, or metadata logic in our code.
- [ ] **Never invoke the engine's `--speakers` mode, and always pass `--no-timestamps`.**
      That mode emits raw per-chunk SRT (a few words per timestamp) and is the exact
      unreadable output we are replacing. The user-facing transcript must be the engine's
      sentence-merged, paragraph-grouped prose.
- [ ] Always single-quote URLs when shelling out (`?` is a zsh glob → "no matches found").
- [ ] Local-first: media and audio never leave the machine; no cloud speech-to-text.
- [ ] Generated artifacts (`transcripts/`, downloaded audio, caches) are gitignored.
- [ ] Skill/command files must carry valid frontmatter (`name`, `description`) in the
      exact shape opencode validates, or opencode filters them out silently.

## Conventions
- Naming: repo `Youtube-scribe`; wrapper `skills/youtube-scribe/scripts/yt-transcript`;
  skill `youtube-scribe`; command `/youtube`. Video slug dirs are `<channel-slug>/<title-slug>`
  (engine's layout).
- Folder layout:
  - `skills/youtube-scribe/` — the skill: `SKILL.md` plus `scripts/` (executable wrapper)
  - `tests/` — bats tests + fixtures
  - `command/youtube.md` — canonical source for the opencode command (opencode-only extra)
  - `spec/` — spec-kit artifacts (this file, product spec, phases, tasks)
  - `transcripts/` — generated output (gitignored)
- Commit message style: imperative, scoped to one concern (e.g. `add yt-transcript wrapper`).
- Definition of Done (global): acceptance criteria met, `bats` green, `shellcheck` clean,
  spec still matches code.

## Routing policy (local-first)
- Default to the local worker matching the task's `difficulty` tag.
- Frontier/cloud is reserved for `gate` (review/verify) and `hard` tasks only.
- Never send secrets/PII to cloud models; those tasks are `local-only`.
