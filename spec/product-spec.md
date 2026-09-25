# Product Spec (Tier 1) — Youtube-scribe

> The ONE master spec. "What & why" from the user's POV — **not** how to build it.
> Keep it shallow but complete. Written once, up front; updated at each phase close.
> This is your real PRD. There is only one.

## 1. Problem & why now
Long YouTube videos take an hour to watch when the useful content is often a few
minutes. Rewatching or scrubbing to find a point is slow, and valuable videos go
unwatched because there is no cheap way to skim them. Existing transcript tools give
you raw captions but stop short: a dump of a few words per timestamp is technically a
transcript but is painful to read, so you still have to piece the whole thing together
to learn what it said. I want one command that turns any YouTube URL into a **readable**
complete transcript (full sentences, no timestamps) plus a TL;DR, generated locally, so
I can decide in seconds whether the video is worth watching and actually read it if it is.

## 2. Target user & top jobs-to-be-done
- Primary user: me, working in opencode on a local-first, two-AMD-GPU Linux box.
- They need to: (1) get the **complete** transcript of a video without watching it;
  (2) read that transcript as **natural, full-sentence prose** (no per-chunk timestamps);
  (3) get a faithful **TL;DR** of what the video actually says; (4) keep the transcript
  and summary as files they can search and reopen; (5) do it with local models and
  without uploading audio.

## 3. Success criteria (product-level, testable)
- [ ] Given a public YouTube URL, one invocation produces a full transcript file and a
      TL;DR file for that video, with no manual steps in between.
- [ ] The transcript is **readable**: full sentences grouped into paragraphs, with **no
      timestamps**, and no raw caption fragments (the "3-4 words per timestamp" dump is
      explicitly rejected).
- [ ] The TL;DR reflects the video's **content** (not just its description) and is
      echoed in the chat.
- [ ] Works for any URL whose captions the engine can fetch, including auto-generated
      captions.
- [ ] Re-running the same URL does not re-download or overwrite an existing TL;DR.
- [ ] Available from any opencode session via the skill and the `/youtube` command.
- [ ] Nothing but caption/metadata requests leaves the machine.

## 4. Scope
**In scope (v1):**
- A thin wrapper that drives the pinned baoyu transcript engine.
- A global opencode skill (`youtube-scribe`) that triggers on a YouTube URL.
- A global opencode command (`/youtube <url>`).
- Per-video output: a **readable full transcript** (sentence-merged, paragraph-grouped,
  no timestamps) and a TL;DR + key points.
- Captions-first: rely on the engine's caption extraction (manual or auto-generated).
  Use the engine's sentence-merged rendering, never its raw per-chunk SRT rendering.

**Explicitly OUT of scope (for now):**
- Whisper / audio transcription fallback for captionless videos (Phase 2).
- Playlists, channels, live streams, and non-YouTube sites.
- Translation, dubbing, speaker diarization, and a web UI.
- A searchable/RAG library across past transcripts.
- Cloud speech-to-text of any kind.

## 5. Non-functional constraints
- **Privacy:** local-first; no media upload, no cloud STT. Only caption/metadata
  requests go to YouTube.
- **Dependencies:** consumes the third-party `baoyu-youtube-transcript` skill (MIT) as
  a pinned, unmodified dependency; does not vendor or edit it.
- **Asset budget:** context overhead matters — install only the one baoyu skill, not
  the whole 20+ skill collection.
- **Platform:** Pop!_OS Linux, bash, `bun` available; opencode as the host agent.
- **Cost:** no paid API; TL;DR runs on the existing local model.

## 6. High-level architecture (one paragraph + a sketch)
A thin bash wrapper (`bin/yt-transcript`) locates the installed baoyu skill directory
and runs its transcript CLI with `bun`, writing the transcript and printing its path.
It deliberately avoids the engine's `--speakers` mode (which dumps raw per-chunk SRT)
and passes `--no-timestamps`, so the output is sentence-merged prose. An opencode skill
and command call that wrapper, read the transcript file, have the host agent write a
TL;DR, save it beside the transcript, and echo it in chat.

```
YouTube URL
   │
   ▼
/youtube command  ──►  youtube-scribe skill (global, opencode)
   │                        │
   │                        ▼
   │              bin/yt-transcript  (our thin wrapper)
   │                        │  locate + run
   │                        ▼
   │          baoyu-youtube-transcript (pinned, unmodified)
   │           InnerTube API → yt-dlp fallback → cache
   │                        │
   │                        ▼
   │       transcripts/<channel-slug>/<title-slug>/transcript.md
   │                        │
   │                        ▼
   └────────────► host agent reads it ──► summary.md + chat TL;DR
```

## 7. Phase map (the plan, kept SHALLOW)
> Phase 0 is ALWAYS the walking skeleton. List later phases as one-liners — do NOT
> detail them yet (that's waterfall). You deep-plan each phase when you reach it.

| # | Phase | One-line goal (the vertical slice) | Status |
|---|-------|------------------------------------|--------|
| 0 | Walking skeleton | install engine + thin wrapper + skill → real transcript and TL;DR for one URL | done |
| 1 | Command & robustness | `/youtube` command, engine discovery/errors, bun fallback, language flags, idempotency | planned |
| 2 | Whisper fallback | captionless videos: `faster-whisper` (CPU) + `--engine` selection | planned |
| 3 | Beyond v1 | GPU Whisper, playlists, non-YouTube sites, searchable library | parked |

## 8. Open questions / risks
- **YouTube blocking:** both caption paths can be defeated by anti-bot responses; the
  engine's `YOUTUBE_TRANSCRIPT_COOKIES_FROM_BROWSER` is the documented escape hatch.
- **Upstream drift:** baoyu is third-party; a future change could break the wrapper.
  Mitigation: pin/record the installed version; keep the engine-dir search defensive.
- **Engine install location:** the skills CLI may place the skill under
  `~/.agents/skills`, `~/.claude/skills`, or `~/.config/opencode/skills`; the wrapper
  must search all three (with an override env var).
- **TLDR fidelity/length for very long transcripts:** may need chunked map-reduce; not
  a Phase 0 concern but flag it.
- **Caption quality:** auto-generated captions can be noisy; acceptable for v1 since
  Whisper fallback is Phase 2.
- **Sentence quality on punctuation-poor captions:** the engine's sentence merge relies
  on sentence-ending punctuation; old auto-captions without it can yield long run-ons or
  occasional fragments (verified on "Me at the zoo"). Acceptable for v1; modern
  auto-captions and manual captions render cleanly on a real test (verified on a
  3Blue1Brown video). Revisit if it proves annoying.

---
_Changelog (update on every phase close — fights spec-code drift):_
- 2026-09-25: created (design brainstorm + reuse decision: adopt baoyu engine, build thin TLDR layer).
- 2026-09-25: transcript must be readable prose (full sentences, no timestamps); root-caused
  the choppy output to the engine's `--speakers` raw-SRT mode and decided to never use it.
- 2026-09-25: Phase 0 done. Shipped `bin/yt-transcript` (pinned engine baoyu-youtube-transcript
  v1.1.0, `--no-timestamps`, engine discovery + bun/npx runner), `skill/youtube-scribe`,
  command `/youtube`, and `scripts/install.sh` (non-interactive engine install). 19/19 tests
  green (incl. real end-to-end on a 3Blue1Brown video), shellcheck clean.
