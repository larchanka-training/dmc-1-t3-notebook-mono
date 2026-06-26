# Implementation Plan: AI-Assisted Notebook Workflow

## Goal

Implement the Version 1 AI-assisted notebook workflow so a user can generate validated `JavaScript` code from a source `text` block through the canonical backend-mediated AI path and insert the result into the notebook as normal editable `code` content.

## Task Artifact

- Current approved task artifact: user request to derive the AI integration direction from `docs/ai-architecture.md`, `docs/plans/mvp-roadmap.md`, and `docs/plans/sprints.md` and persist it as a reusable markdown plan
- Roadmap source: `docs/plans/mvp-roadmap.md` Stage 7, `AI-Assisted Notebook Workflow`
- Canonical backend AI contract: `api/docs/ai_contract.md`
- High-level AI architecture: `docs/ai-architecture.md`
- System architecture constraints: `docs/system_architecture.md`
- Frontend architecture constraints: `ui/docs/ui_architecture.md`
- Backend architecture constraints: `api/docs/api_architecture.md`
- Upstream dependency plans:
  - `docs/plans/01-auth-backend-plan.md`
  - `docs/plans/02-notebook-persistence-plan.md`

## Assumptions

- This plan covers the first executable Stage 7 AI slice only, not every AI-related idea currently mentioned in `docs/plans/sprints.md`.
- The canonical Version 1 AI flow remains `frontend -> backend API -> provider`, with `AWS Bedrock` as the primary provider path and no direct browser-to-provider production path.
- `WebLLM` is not required for the first delivery slice and should be treated as deferred or stretch scope unless the team explicitly promotes it later.
- Notebook persistence, local-first working copy behavior, and manual sync are either already landing or stable enough that AI can rely on the real notebook/block model instead of mock-only editor state.
- The first slice should generate `JavaScript` only and should not expand into multi-language output, durable prompt history, or a new notebook `ai` block type.
- AI-generated code remains untrusted, is never executed on the backend, and becomes ordinary editable notebook content only after frontend insertion.

## Architecture Notes

- Preserve the fixed Version 1 AI decisions from `docs/ai-architecture.md`:
  - AI is block-scoped
  - the source surface is an existing `text` block
  - the backend performs prompt screening before provider invocation
  - deterministic validation is preferred over LLM-based validation where possible
  - invalid extracted code must go through bounded repair retry before final failure
- Do not introduce a durable notebook `ai` block type or any notebook schema expansion for prompt/session history.
- Keep the backend under the documented feature-driven structure: `api/app/features/ai/{router,schemas,service,repository,models}.py` or equivalent internal helpers where needed.
- Keep the frontend under the documented FSD boundaries with AI behavior in `ui/src/features/ai/` and editor integration in the existing editor slices.
- Default context behavior must act as `scope: this`; broader notebook context must be bounded and deterministic.
- The first implementation slice should use the minimal user-visible flow:
  - user writes or edits a source `text` block
  - user triggers AI generation for that block
  - frontend builds bounded context and sends a backend request
  - backend validates, screens, invokes provider, extracts code, validates syntax, and retries repair when needed
  - frontend inserts the returned code into the next empty `code` block or creates a new `code` block after the source block
- Runtime outputs remain non-durable by default and must not silently become part of persisted notebook content through AI flows.

## Out of Scope for This Direction

- Direct browser-to-provider production access
- Durable AI prompt history or provenance data model
- A new notebook `ai` block type
- Broad full-notebook context by default
- Arbitrary use of execution outputs as always-on AI context
- Advanced revision UX beyond the documented `convert code to text for AI revision` simplification
- Cost analytics, token-budget dashboards, or advanced provider routing

## Tasks

### Phase 1: Scope and Contract Baseline

## Task 1: `T3/BTF -> RESEARCH: Fix the Stage 7 AI scope and first delivery slice`

**Description:** Convert the current Sprint 2 AI ideas into one canonical Stage 7 delivery scope aligned with `docs/ai-architecture.md` and the roadmap. This task removes conflicting assumptions such as `Prompt Cell` as a durable concept or `WebLLM` as a required first-class path.

**Acceptance criteria:**
- [ ] The first AI slice is fixed as `text block -> backend AI endpoint -> validated JavaScript -> insert code block`.
- [ ] The plan explicitly states that Version 1 does not introduce a durable `ai` notebook block type.
- [ ] The plan fixes `backend-first` as canonical and marks `WebLLM` as deferred or stretch scope.
- [ ] Out-of-scope items are documented so implementation does not expand into unrelated AI features.

**Verification:**
- [ ] Manual cross-check against `docs/ai-architecture.md`, `docs/project.md`, `docs/system_architecture.md`, and `ui/docs/ui_architecture.md`
- [ ] Review confirms no planned task contradicts fixed Version 1 AI decisions

**Dependencies:** None

**Likely files or areas:**
- `docs/plans/05-ai-integration-plan.md`
- `docs/ai-architecture.md`
- `docs/plans/mvp-roadmap.md`

**Scope:** S

## Task 2: `T3/BTF -> BACK: Define the AI request and response contract`

**Description:** Define the stable backend API contract for block-scoped AI generation so frontend and backend can proceed in parallel against one request/response model. The contract must carry only bounded notebook context and must return normalized code and normalized failures.

**Acceptance criteria:**
- [ ] Request schema defines source block identity, normalized prompt text, scope, bounded context blocks, and insertion strategy.
- [ ] Response schema defines request id, code string, provider/model metadata, validation result, and normalized error shape.
- [ ] The contract explicitly supports `JavaScript` generation only.
- [ ] Request-size and validation constraints are documented clearly enough for frontend and backend implementation.

**Verification:**
- [ ] Manual review against `docs/ai-architecture.md` sections on context builder and end-to-end flow
- [ ] Backend and frontend review confirms the contract is sufficient for parallel implementation

**Dependencies:** `T3/BTF -> RESEARCH: Fix the Stage 7 AI scope and first delivery slice`

**Likely files or areas:**
- `api/app/features/ai/`
- `ui/src/shared/api/` or feature-local API wiring
- `api/docs/ai_contract.md`

**Scope:** M

### Phase 2: Backend AI Pipeline

## Task 3: `T3/BTF -> BACK: Implement the authenticated backend AI endpoint and provider boundary`

**Description:** Build the canonical backend path for AI generation: authenticated endpoint, prompt screening, provider adapter boundary, provider call orchestration, and normalized responses. This is the first executable backend slice of Stage 7.

**Acceptance criteria:**
- [ ] `POST /api/v1/ai/code-blocks/generate` exists under the documented backend architecture.
- [ ] The endpoint requires authenticated session access.
- [ ] Request-size limits and prompt-screening checks are enforced before provider invocation.
- [ ] Provider access is abstracted behind an adapter boundary suitable for `AWS Bedrock`.
- [ ] Provider failures are mapped to normalized retryable vs non-retryable error responses.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/ai/test_endpoint.py -q`
- [ ] OpenAPI schema inspection confirms the route contract

**Dependencies:**
- `T3/BTF -> BACK: Define the AI request and response contract`
- `T3/BTF -> BACK: Add shared auth session and current-user dependencies`

**Likely files or areas:**
- `api/app/features/ai/router.py`
- `api/app/features/ai/schemas.py`
- `api/app/features/ai/service.py`
- `api/app/integrations/`

**Scope:** M

## Task 4: `T3/BTF -> BACK: Add deterministic extraction, JavaScript validation, and bounded repair retry`

**Description:** Implement the part of the AI pipeline that turns provider output into safe insertable notebook code. The backend must extract code, validate `JavaScript` syntax deterministically, and perform bounded repair retry when initial extraction or syntax validation fails.

**Acceptance criteria:**
- [ ] Provider responses with markdown fences or explanation text are normalized to a code string.
- [ ] Deterministic `JavaScript` syntax validation runs on extracted code.
- [ ] Invalid extracted code triggers bounded repair retry with validation feedback.
- [ ] Final failures return normalized validation errors without leaking raw internal provider details.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/ai/test_validation_pipeline.py -q`
- [ ] Manual review confirms no backend-side execution of notebook code occurs

**Dependencies:** `T3/BTF -> BACK: Implement the authenticated backend AI endpoint and provider boundary`

**Likely files or areas:**
- `api/app/features/ai/service.py`
- `api/app/features/ai/` internal helper modules
- `api/tests/integration/ai/`

**Scope:** M

### Phase 3: Frontend AI Flow

## Task 5: `T3/BTF -> FRONT: Implement block-scoped AI action and transient UI state`

**Description:** Add the frontend AI entry point for a source `text` block with transient UI state only. This task covers the user-visible action, request lifecycle, and error handling without changing the durable notebook schema.

**Acceptance criteria:**
- [ ] A source `text` block can trigger AI generation from the notebook editor.
- [ ] Frontend stores AI request lifecycle in transient UI state, not in durable notebook content.
- [ ] The UI shows `idle`, `submitting`, `success`, and `error` states for the AI request flow.
- [ ] Frontend uses the backend API contract and does not connect directly to a provider.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] UI integration tests cover idle, loading, success, and error states
- [ ] Manual editor check confirms no notebook schema mutation is introduced for AI state

**Dependencies:** `T3/BTF -> BACK: Define the AI request and response contract`

**Likely files or areas:**
- `ui/src/features/ai/`
- `ui/src/features/editor/`
- relevant Zustand slices/selectors

**Scope:** M

## Task 6: `T3/BTF -> FRONT: Build the deterministic context builder and code insertion flow`

**Description:** Implement the frontend logic that assembles bounded notebook context and inserts returned code into the correct place in the notebook. This task is where AI meets the real notebook/block model from persistence, local-first, and sync work.

**Acceptance criteria:**
- [ ] Default behavior is equivalent to `scope: this`.
- [ ] Minimal `scope: notebook` support includes only blocks from the notebook start through the source block, in order, within a bounded request budget.
- [ ] Frontend inserts generated code into the next empty `code` block after the source block or creates a new `code` block there.
- [ ] The insertion flow works with the actual notebook block model used by persistence and sync, not a parallel AI-only representation.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Unit tests cover `scope: this`, bounded `scope: notebook`, and insertion-target selection
- [ ] Manual notebook flow confirms generated code lands in the expected block position

**Dependencies:**
- `T3/BTF -> FRONT: Implement block-scoped AI action and transient UI state`
- notebook persistence / local-first / sync contracts stable enough for block insertion logic

**Likely files or areas:**
- `ui/src/features/ai/model/`
- `ui/src/features/editor/model/`
- notebook block utilities and store logic

**Scope:** M

### Phase 4: Quality and Operations Hardening

## Task 7: `T3/BTF -> QA: Build the AI acceptance suite for the first vertical slice`

**Description:** Turn the broad Sprint 2 AI test-suite idea into an acceptance-oriented suite for the actual first implementation slice. The suite should verify backend contract behavior and the notebook insertion UX rather than broad prompt catalogs detached from the implemented feature.

**Acceptance criteria:**
- [ ] Test cases exist for happy-path generation, invalid output repaired successfully, empty provider response, timeout, provider failure, and policy rejection.
- [ ] Test cases cover insertion into the next empty `code` block and creation of a new `code` block when needed.
- [ ] QA scope explicitly distinguishes backend contract tests from UI or E2E notebook flow checks.
- [ ] Prompt coverage is bounded to implemented scenarios rather than generic model exploration.

**Verification:**
- [ ] `docs/ai-test-cases.md` or an agreed equivalent QA artifact exists and maps to implemented behaviors
- [ ] At least one automated backend suite and one UI/E2E AI flow are defined
- [ ] `docs/qa_plan.md` is reviewed for any AI-specific updates needed after implementation

**Dependencies:**
- `T3/BTF -> BACK: Add deterministic extraction, JavaScript validation, and bounded repair retry`
- `T3/BTF -> FRONT: Build the deterministic context builder and code insertion flow`

**Likely files or areas:**
- `docs/qa_plan.md`
- `docs/ai-test-cases.md`
- backend AI tests
- UI/E2E AI tests

**Scope:** S

## Task 8: `T3/BTF -> DEVOPS: Prepare private AI runtime configuration and observability`

**Description:** Add the minimum operational support needed for the canonical backend AI path: provider credentials, safe configuration, request logging, and endpoint protection controls. This is infrastructure support for the product slice, not a replacement for backend implementation.

**Acceptance criteria:**
- [ ] Bedrock-related secrets and config are available only to trusted backend runtime.
- [ ] AI request logging excludes secrets and avoids unnecessary prompt/content leakage.
- [ ] Basic rate limiting or protective throttling is defined for the endpoint.
- [ ] Local/dev and deployed operational failure modes are documented clearly enough for the team to run the feature.

**Verification:**
- [ ] Manual config review confirms no provider credential exposure to the browser
- [ ] Environment validation confirms backend can resolve required config at startup
- [ ] Deployment or runtime docs document the required AI environment settings

**Dependencies:** `T3/BTF -> BACK: Implement the authenticated backend AI endpoint and provider boundary`

**Likely files or areas:**
- backend config and environment docs
- deployment/runtime configuration
- logging or operational docs

**Scope:** S

## Task 9: `T3/BTF -> BACK: Add multilingual prompt-policy screening for code-generation intent`

**Description:** Extend the existing backend prompt-policy screening so the canonical AI endpoint accepts code-generation and code-revision requests expressed in supported non-English languages, starting with Russian, while still rejecting non-code intent and unsafe prompt-injection attempts before provider invocation.

**Acceptance criteria:**
- [ ] Backend prompt screening accepts supported Russian code-intent prompts such as requests to create a function, component, helper, or refactor code, without requiring prompt translation on the client.
- [ ] Backend prompt screening continues to reject non-code prompts such as explanation, summarization, and general-chat requests in both English and supported Russian phrasing.
- [ ] Unsafe prompt-injection and policy-evasion screening covers both existing English patterns and the supported Russian equivalents needed for the first multilingual slice.
- [ ] The public AI endpoint contract remains unchanged: no new required request fields, no prompt-language field, and no relaxation of the `context.language: javascript` rule.
- [ ] The implementation uses deterministic backend-side screening as the primary decision path and does not silently turn the endpoint into a general multilingual chat classifier.
- [ ] Automated backend coverage exists for at least:
- [ ] English code-intent pass
- [ ] Russian code-intent pass
- [ ] English non-code reject
- [ ] Russian non-code reject
- [ ] English unsafe reject
- [ ] Russian unsafe reject

**Verification:**
- [ ] `cd api && .venv/bin/python -m pytest tests/unit/ai -q`
- [ ] `cd api && .venv/bin/python -m pytest -m integration tests/integration/ai/test_endpoint.py -q`
- [ ] Manual contract review confirms no API payload shape changes were introduced for multilingual support

**Dependencies:**
- `T3/BTF -> BACK: Implement the authenticated backend AI endpoint and provider boundary`
- `T3/BTF -> QA: Build the AI acceptance suite for the first vertical slice`

**Likely files or areas:**
- `api/app/features/ai/service.py` or extracted prompt-screening helper module
- `api/tests/unit/ai/`
- `api/tests/integration/ai/`
- `docs/ai-test-cases.md`
- `api/docs/ai_contract.md` and/or `docs/ai-architecture.md` if multilingual policy wording needs clarification

**Scope:** S

## Recommended Execution Order

1. `T3/BTF -> RESEARCH: Fix the Stage 7 AI scope and first delivery slice`
2. `T3/BTF -> BACK: Define the AI request and response contract`
3. `T3/BTF -> BACK: Implement the authenticated backend AI endpoint and provider boundary`
4. `T3/BTF -> FRONT: Implement block-scoped AI action and transient UI state`
5. `T3/BTF -> BACK: Add deterministic extraction, JavaScript validation, and bounded repair retry`
6. `T3/BTF -> FRONT: Build the deterministic context builder and code insertion flow`
7. `T3/BTF -> QA: Build the AI acceptance suite for the first vertical slice`
8. `T3/BTF -> DEVOPS: Prepare private AI runtime configuration and observability`
9. `T3/BTF -> BACK: Add multilingual prompt-policy screening for code-generation intent`

## Checkpoints

1. **Checkpoint 1: The first AI slice is unambiguous**
   The team has one fixed Stage 7 scope, one contract, and no remaining confusion between `Prompt Cell`, durable AI content, backend-only flow, and optional fallback ideas.

2. **Checkpoint 2: The backend AI path is real**
   Authenticated frontend requests can reach a real backend endpoint that screens input, calls the provider boundary, validates extracted code, and returns normalized outcomes.

3. **Checkpoint 3: AI works inside the notebook flow**
   A user can generate `JavaScript` from a source `text` block and see the result inserted into the correct notebook `code` block position using the real block model.

4. **Checkpoint 4: The feature is testable and operable**
   AI happy-path and failure-path checks exist across backend and UI layers, and the team has minimal operational guidance for running the canonical backend AI path.

5. **Checkpoint 5: Prompt policy is multilingual without expanding endpoint scope**
   The backend continues to enforce code-only and unsafe-prompt rules, but supported code-intent prompts are no longer implicitly English-only.

## Risks and Mitigations

- **Risk:** notebook persistence, local-first persistence, or sync contracts may still be moving while AI integration starts.
  **Mitigation:** lock the first AI slice to the canonical notebook/block shape and avoid introducing a parallel AI-specific content model.

- **Risk:** `WebLLM` or other fallback ideas may expand scope before the canonical backend path exists.
  **Mitigation:** keep `WebLLM` explicitly deferred until the backend-first slice is complete and verified.

- **Risk:** provider output quality may be inconsistent, causing fragile frontend behavior.
  **Mitigation:** keep extraction and syntax validation on the backend and return normalized errors instead of raw provider text.

- **Risk:** prompt screening, request sizing, and error mapping could be under-specified and create security or reliability gaps.
  **Mitigation:** define contract constraints early and include them in backend tests and DevOps configuration review.

- **Risk:** prompt policy may behave as if the endpoint is English-only, causing false rejections for valid code requests in supported team languages.
  **Mitigation:** add explicit multilingual prompt-screening coverage as a bounded backend follow-up without changing the public API contract or broadening the endpoint into general chat.

- **Risk:** QA could overinvest in broad prompt catalogs before the implemented slice is stable.
  **Mitigation:** tie the acceptance suite only to implemented feature behavior and expand prompt coverage later.

## Open Questions

- Should the first implementation of `scope: notebook` be delivered in the initial slice, or should the team land only `scope: this` and defer broader context to a follow-up task?
- Which deterministic `JavaScript` syntax validation approach should the backend use first so it remains simple, testable, and aligned with the existing stack?
- Does the current frontend editor state already expose the exact block insertion hooks AI needs, or should a small editor-integration preparation task be added before Task 6 starts?
- Should `docs/ai-test-cases.md` live at the docs root, or should the team prefer a future domain-specific QA subdirectory once the docs structure is reorganized?
