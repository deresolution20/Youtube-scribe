# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-25

### Added
- `youtube-scribe` Agent Skill: given a YouTube URL, produces a readable
  full-sentence transcript (no timestamps) plus a `summary.md` TL;DR written
  beside it.
- `yt-transcript` wrapper at `skills/youtube-scribe/scripts/yt-transcript`:
  locates the installed baoyu engine, runs it with `--no-timestamps`, and prints
  the transcript path. It never uses the engine's unreadable `--speakers` mode.
- Pinned engine assertion (`baoyu-youtube-transcript` 1.1.0), with an override via
  `--allow-engine-version` or `YT_SCRIBE_ALLOW_ENGINE_VERSION=1`.
- `/youtube` opencode command source (`command/youtube.md`).
- `scripts/install.sh` for local opencode development: symlinks the skill, command,
  and wrapper; the engine install is opt-in via `YT_SCRIBE_INSTALL_ENGINE=1`.
- README, MIT LICENSE, and this changelog.

### Notes
- The transcript engine is a separate third-party skill and is not bundled. Install
  it once with
  `npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g`.
- Local-first: media and audio never leave the machine; only caption and metadata
  requests go to YouTube.

[1.0.0]: https://github.com/deresolution20/Youtube-scribe/releases/tag/v1.0.0