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
