# Task Spec (Tier 3) — <Phase N> / Task <M>: <NAME>

> The atomic unit (your "milestone"). One agent, one scoped context, one verifiable
> result. This is what gets routed to a local GPU. Keep it TINY.

**Parent:** Phase <N> → Task <M>
**Blocked by:** <task #s or "none">
**difficulty:** `easy` | `hard` | `gate` | `local-only`   ← the orchestrator routes on this
**routes to:** <auto-filled: 7900 XTX | R9700 | frontier>

## What to build
_One or two sentences. Precise. No ambiguity._

## Files this task may touch
> The agent must NOT edit anything outside this list.
- `path/to/file`

## Acceptance criteria (contract — MUST be testable)
> "Looks good" is not a contract. Give concrete, checkable conditions: sample
> inputs→outputs, a unit test that must pass, a command that must exit 0.
- [ ]
- [ ] Tests pass: `<command>`

## Context the worker needs (and ONLY this)
> Scoped context = why this exists, what constraints apply, what it may use. Do NOT
> paste the whole repo/history (context rot). (Ref: the "Spine", arXiv 2606.27045)
- Why:
- Constraints (from constitution):
- May use (existing functions/modules):

## Verification gate (run before merge)
- [ ] Acceptance criteria all met
- [ ] Tests green
- [ ] Reviewed by `gate` model (frontier) if difficulty was `hard`
- [ ] Spec still matches code (no drift)

---
_Result / notes:_
