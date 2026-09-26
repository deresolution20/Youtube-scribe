# YouTube Scribe

[![skills.sh](https://skills.sh/b/deresolution20/Youtube-scribe)](https://skills.sh/deresolution20/Youtube-scribe)

Turn a YouTube URL into a readable, full-sentence transcript (no timestamps) plus a
TL;DR summary saved beside it. It is a skill for agents that support the
[Agent Skills](https://agentskills.io) format, published on
[skills.sh](https://www.skills.sh).

This skill is a thin wrapper. The transcript engine itself is the separate
**baoyu-youtube-transcript** skill and is not bundled.

## Prerequisites

- The `baoyu-youtube-transcript` skill, installed separately:

  ```bash
  npx skills add JimLiu/baoyu-skills --skill baoyu-youtube-transcript -g
  ```

- `bun` (preferred) or `npx` on `PATH`, to run the engine.

The wrapper refuses to run against an engine version other than the pinned
`1.1.0`. Override with `--allow-engine-version` or
`YT_SCRIBE_ALLOW_ENGINE_VERSION=1` if you have deliberately moved ahead.

## Install

### As a skill (any supported agent)

```bash
npx skills add deresolution20/Youtube-scribe
```

### Local opencode development

```bash
scripts/install.sh
```

This symlinks the skill into `~/.config/opencode/skills/youtube-scribe`, the
`/youtube` command into `~/.config/opencode/command/`, and the wrapper into
`~/.local/bin/`. It does **not** install the engine unless you set
`YT_SCRIBE_INSTALL_ENGINE=1`.

## Usage

The skill resolves `{baseDir}` to its own directory and runs:

```bash
{baseDir}/scripts/yt-transcript '<youtube-url>'
```

Flags:

| Flag | Meaning |
|------|---------|
| `--out-dir <dir>` | Base output directory (default `./transcripts`) |
| `--languages <codes>` | Comma-separated language priority list (default `en`) |
| `--refresh` | Ignore the engine cache and re-fetch |
| `--engine-dir <dir>` | Explicit baoyu engine directory |
| `--allow-engine-version` | Skip the pinned engine version check |
| `--print-engine-dir` | Print the resolved engine directory and exit |
| `--print-runner` | Print the runner command and exit |

On success the last line of stdout is the transcript file path. The agent then
reads it and writes `summary.md` beside it (TL;DR, key points, notable details).
An existing `summary.md` is never overwritten.

Environment overrides: `BAOYU_SKILL_DIR`, `YT_SCRIBE_RUNNER`,
`YT_SCRIBE_ALLOW_ENGINE_VERSION`.

## Development

```bash
bats --print-output-on-failure tests/     # unit + integration
shellcheck skills/youtube-scribe/scripts/yt-transcript scripts/install.sh
RUN_NETWORK_TESTS=1 bats tests/e2e.bats   # opt-in network tests
```

## License

[MIT](LICENSE)
