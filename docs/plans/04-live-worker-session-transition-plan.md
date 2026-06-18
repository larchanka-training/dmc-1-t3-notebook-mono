# Stage 6 Summary: Transition from Replay Runtime to Live Worker Session

## Status

- `done`

## Purpose

This artifact records the completed Stage 6 migration from replay-based runtime restoration to a live `Web Worker` execution session.

It remains in the planning set as historical context for:

- why the migration was needed
- what behavior is now accepted as the current runtime model
- which Stage 6 slices closed the migration
- which runtime boundaries still remain in force

## Context

- [docs/project.md](../project.md)
- [docs/system_architecture.md](../system_architecture.md)
- [docs/tech_stack.md](../tech_stack.md)
- [docs/qa_plan.md](../qa_plan.md)
- [ui/docs/runtime_architecture.md](../../ui/docs/runtime_architecture.md)
- [ui/docs/ui_architecture.md](../../ui/docs/ui_architecture.md)
- [ui/docs/adr/ADR-003-runtime-execution-model.md](../../ui/docs/adr/ADR-003-runtime-execution-model.md)
- [docs/plans/tasks/live-worker-session-01-target-semantics-and-contracts.md](./tasks/live-worker-session-01-target-semantics-and-contracts.md)
- [docs/plans/tasks/live-worker-session-02-runtime-core-migration.md](./tasks/live-worker-session-02-runtime-core-migration.md)
- [docs/plans/tasks/live-worker-session-03-regression-coverage-and-qa.md](./tasks/live-worker-session-03-regression-coverage-and-qa.md)
- [docs/plans/tasks/live-worker-session-04-docs-and-roadmap-alignment.md](./tasks/live-worker-session-04-docs-and-roadmap-alignment.md)

## Why Stage 6 existed

Stage 5 execution MVP already shipped the basic user commands:

- `run current`
- `run all`
- `run from here`
- output binding
- stop/timeout UI states

But the earlier runtime restored session state by replaying previously executed source blocks. That model created the risks Stage 6 was meant to remove:

- repeated upstream side effects during downstream reruns
- redeclaration failures on repeated top-level runs
- latency growth as replay history grew
- semantics that diverged from the project definition of an `execution session`

## Accepted current runtime behavior

The current frontend runtime model is now:

- notebook execution stays client-side
- execution orchestration stays frontend-side
- code runs inside a dedicated `Web Worker`
- the worker owns the live in-memory `execution session`
- `run current` reuses the current live worker session
- `run from here` reuses the current live worker session and executes only the block range selected by the orchestrator
- `run all` resets the worker session before full top-to-bottom execution
- `stop` terminates the active worker and guarantees that the next run starts in a clean worker session
- timeout terminates the active worker and guarantees that the next run starts in a clean worker session
- syntax error or runtime error in one block does not implicitly reset the worker session by itself
- when required upstream state is missing after reset, stop, timeout, or fresh session start, the runtime must surface the missing-state case explicitly instead of silently rebuilding it through hidden replay
- outputs remain transient execution artifacts rather than durable notebook content

## Closed Stage 6 slices

### Slice 1. Contracts and target semantics

Closed by:

- [docs/plans/tasks/live-worker-session-01-target-semantics-and-contracts.md](./tasks/live-worker-session-01-target-semantics-and-contracts.md)

Outcome:

- Stage 6 semantics for live session reuse, reset boundaries, missing upstream state, and post-error validity were fixed explicitly in docs and task contracts.

### Slice 2. Runtime core migration

Closed by:

- [docs/plans/tasks/live-worker-session-02-runtime-core-migration.md](./tasks/live-worker-session-02-runtime-core-migration.md)

Outcome:

- runtime core no longer reconstructs session state by replaying prior source history
- repeated top-level runs work in the live worker session
- downstream reruns no longer depend on hidden upstream replay

### Slice 3. Regression coverage and QA

Closed by:

- [docs/plans/tasks/live-worker-session-03-regression-coverage-and-qa.md](./tasks/live-worker-session-03-regression-coverage-and-qa.md)

Outcome:

- runtime-level regression coverage exists for session reuse, reset, stop, and timeout lifecycle
- integration-level regression coverage exists for live-session reuse, timeout recovery, and error recovery
- manual Stage 6 QA guidance exists for mixed notebooks with `text` and `code` blocks

### Slice 4. Documentation and roadmap alignment

Closed by:

- [docs/plans/tasks/live-worker-session-04-docs-and-roadmap-alignment.md](./tasks/live-worker-session-04-docs-and-roadmap-alignment.md)

Outcome:

- runtime docs, ADR notes, QA checklist, and this Stage 6 artifact describe live worker session behavior as the current implemented model

## Boundaries that remain in force

Stage 6 did not change these architectural limits:

- the runtime is still client-side
- the orchestrator is still frontend-side
- the worker is still the primary execution boundary
- stop and timeout are still coarse-grained terminate-and-recreate mechanisms
- outputs are still latest-run transient artifacts, not durable notebook state
- the runtime still must not receive app stores, persistence adapters, backend credentials, or raw `HTTP-only` cookie access
- notebook-order range selection still belongs to the orchestrator, not to the worker

## Verification record

The migration is considered closed based on the completed Stage 6 slices:

- targeted runtime contract alignment in Slice 1
- runtime-core and worker-bridge verification in Slice 2
- regression and QA coverage in Slice 3
- documentation diff review and wording cleanup in Slice 4

See the linked task artifacts for the exact verification commands and any manual checks that were or were not run in each slice.

## Remaining follow-ups

No additional runtime migration slice remains open in this plan.

Potential future runtime work, if separately approved, belongs to new tasks rather than to this closed migration artifact. Examples include:

- console capture or richer streaming outputs
- runtime policy for `fetch`
- future DOM-oriented execution requirements

## Outcome

Stage 6 is complete.

Replay-based session restoration is no longer the current or target runtime model for Version 1. The accepted model is a live worker-owned `execution session` with explicit reset boundaries, explicit missing-state behavior after session replacement, and regression coverage aligned with that behavior.
