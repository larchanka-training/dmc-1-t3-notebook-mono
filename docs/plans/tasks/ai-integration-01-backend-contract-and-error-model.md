# T3/BTF -> BACK: Fix the AI backend contract and error model

## Status

- `done`

## Goal

Fix the Version 1 backend contract for block-scoped AI generation so backend, frontend, and QA can implement and verify the Stage 7 AI slice against one canonical request/response and error model.

## Canonical Artifact

The long-lived canonical backend contract is now defined in:

- [api/docs/ai_contract.md](../../../api/docs/ai_contract.md)

This task file is a completed work item and is no longer the primary source of truth for the contract itself.

## Scope Completed

- fixed the canonical route `POST /api/v1/ai/code-blocks/generate`
- fixed the Version 1 request payload shape and validation rules
- fixed the success response shape and validation metadata
- fixed the normalized backend error catalog, HTTP mapping, and retryability semantics
- fixed the pre-provider validation and policy gates
- fixed the deterministic post-provider extraction, syntax validation, and bounded repair retry rules
- fixed the backend/frontend insertion responsibility boundary
- aligned contract examples with the AI architecture and QA artifacts

## Documentation Impact

Primary contract artifact:

- [api/docs/ai_contract.md](../../../api/docs/ai_contract.md)

Aligned references:

- [docs/ai-architecture.md](../../ai-architecture.md)
- [api/docs/api_architecture.md](../../../api/docs/api_architecture.md)
- [docs/ai-test-cases.md](../../ai-test-cases.md)
- [ui/docs/ui_architecture.md](../../../ui/docs/ui_architecture.md)

## Verification

- [x] the canonical backend contract was moved into `api/docs/ai_contract.md`
- [x] the task remains as a completed planning/execution artifact only
- [x] related AI task files and architecture docs can reference the new canonical location
- [ ] backend/frontend human review still needs explicit sign-off if required for the delivery workflow

## Completion Update

- the canonical AI backend contract was moved out of `docs/plans/tasks/` into `api/docs/ai_contract.md`
- the task remains as the historical work item that introduced and stabilized that contract
