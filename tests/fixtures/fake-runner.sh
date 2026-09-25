#!/usr/bin/env bash
# Test double for the transcript engine: prints each argument on its own line,
# then a transcript path, then exits with FAKE_RUNNER_EXIT (default 0).
for arg in "$@"; do printf 'ARG[%s]\n' "$arg"; done
printf '%s\n' "${FAKE_TRANSCRIPT_PATH:-/tmp/fake/transcript.md}"
exit "${FAKE_RUNNER_EXIT:-0}"
