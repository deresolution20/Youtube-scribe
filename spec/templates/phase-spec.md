# Phase Spec (Tier 2) — Phase <N>: <NAME>

> Copy one per phase. This is the epic + technical design for ONE vertical slice.
> **Generate this only when you START the phase**, not at project kickoff.
> Do a planning pass first (brainstorm, and /deep-research if the phase has unknowns).

**Parent:** Product Spec → Phase <N>
**Depends on phases:** <e.g. Phase 0>

## 1. Goal of this slice
_The narrow-but-complete path through every layer this phase delivers. One sentence of
user value._

## 2. What "done" looks like (phase acceptance criteria)
- [ ]
- [ ]

## 3. Technical design (the "how" the Product Spec left out)
_Data model changes, APIs/interfaces, key decisions, libraries. This is the design doc
for this phase only._

## 4. Contract / interface with the rest of the system
> What neighbors are allowed to see. Keep internal design private to this phase's tasks
> — expose only the contract, to avoid context bloat downstream.
> (Ref: contract/design separation, arXiv 2606.27045)
- Inputs:
- Outputs:
- Public interface(s):

## 5. Task breakdown (Tier 3 — the atomized work)
> In dependency order. Each becomes a `task-spec.md`. Keep each small enough to build +
> verify in ONE scoped agent context.

| # | Task | difficulty (easy/hard/gate) | Blocked by | Status |
|---|------|-----------------------------|------------|--------|
| 1 | | easy | – | todo |
| 2 | | hard | 1 | todo |
| 3 | verify slice end-to-end | gate | 2 | todo |

## 6. Out of scope for this phase
-

---
_On phase close: check every acceptance criterion, demo the slice, then update the
Product Spec changelog and phase map._
