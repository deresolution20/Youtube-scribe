# Youtube-scribe

This app follows the workspace Kickoff System (spec-driven development).
Full method: `../spec-kit/README.md` · fundamentals: `../spec-kit/docs/fundamentals.md`

## Read first, every session

1. `spec/constitution.md` — non-negotiable rules for this app
2. `spec/product-spec.md` — the ONE PRD; phase map + changelog at the bottom
3. The currently open phase spec in `spec/phases/` (if any)

## How work happens

- Claude Code is the **orchestrator**: it writes/refines specs, decomposes work, and
  runs the verification gate. The spec is the source of truth; code is generated
  against it.
- One phase at a time. **Phase 0 is always the walking skeleton.**
- Deep-plan a phase only when starting it: copy `spec/templates/phase-spec.md` to
  `spec/phases/phase-<N>-<name>.md` and fill it (research first if there are unknowns).
- Decompose the phase into task specs (`spec/templates/task-spec.md`), in dependency
  order. Each task: one scoped context, an explicit file allowlist, testable
  acceptance criteria, and a `difficulty` tag (`easy` | `hard` | `gate` | `local-only`).
- Routing by difficulty is defined in `../spec-kit/docs/local-llm-routing.md`. Until
  the local endpoints are wired up, Claude Code does the work itself — but keep
  tagging tasks so routing can be switched on later.
- **Verification gate before merge:** acceptance criteria met, tests green, spec still
  matches code. "Looks good" is not a contract.
- On phase close: demo the slice, update `spec/product-spec.md` (phase map +
  changelog), then start the next phase in a **fresh session**.

## Parking lot

Scope creep and new ideas go to `spec/IDEAS.md`, never into the current phase.
