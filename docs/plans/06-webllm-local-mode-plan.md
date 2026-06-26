# Implementation Plan: WebLLM Local Mode

## Goal

Add an optional frontend-side `WebLLM` local generation mode to the Version 1 AI-assisted notebook workflow without changing the canonical backend-first AI architecture, backend API contract, or the default production provider path.

## Task Artifact

- Current approved task artifact: user request to derive and persist an implementation plan for `WebLLM` under the current Stage 7 AI architecture
- Canonical AI direction: `docs/ai-architecture.md`
- Current AI implementation direction plan: `docs/plans/05-ai-integration-plan.md`
- Product AI status note: `docs/sprints/sprint-2/ai-implementation-status-for-product-owner.md`
- Roadmap context: `docs/plans/mvp-roadmap.md` Stage 7, `AI-Assisted Notebook Workflow`
- Frontend architecture constraints: `ui/docs/ui_architecture.md`
- System architecture constraints: `docs/system_architecture.md`
- Technology constraints: `docs/tech_stack.md`

## Assumptions

- The canonical Version 1 AI path remains `frontend -> backend API -> Bedrock`.
- `WebLLM` is not promoted to the default generation path and is not required for the first delivery slice already covered by `docs/plans/05-ai-integration-plan.md`.
- The existing frontend AI request flow, context-builder logic, and code-insertion flow are already stable enough to be reused by a second provider path.
- `WebLLM` is introduced only as an explicit local mode and/or a retry fallback after retryable backend failures.
- Explicit local `WebLLM` mode is allowed for unsynced local working copies because it does not require server-side notebook identity or backend provider access; this does not relax the synced-notebook prerequisite for the canonical backend path.
- The notebook durable block model remains unchanged: Version 1 still uses only `text` and `code` blocks.
- `WebLLM` output remains untrusted and becomes ordinary editable notebook content only after the existing insertion flow accepts it.
- The project should avoid creating a second AI product with different semantics; `WebLLM` must fit inside the same notebook UX, not branch into a separate chat-like experience.

## Architecture Notes

- Preserve the fixed AI decisions from `docs/ai-architecture.md`:
  - block-scoped AI
  - source surface is an existing `text` block
  - `JavaScript` generation only
  - no durable `ai` notebook block type
  - canonical backend-first provider path
- Do not change the backend contract or route shape of `POST /api/v1/ai/code-blocks/generate` for `WebLLM`.
- Keep `WebLLM` entirely inside frontend boundaries under `ui/src/features/ai/`; do not introduce a browser-to-backend shadow transport or fake backend mode.
- Reuse the deterministic context builder and existing insertion strategy so provider choice does not change notebook semantics.
- Reuse the same normalized frontend AI request shape at the provider-abstraction boundary, while allowing the local provider to consume a reduced subset of that context internally when browser/runtime limits require it.
- Expose provider identity in frontend state and UI so users can tell whether generated code came from `bedrock` or `webllm`.
- Keep `WebLLM` behind a feature flag or equivalent runtime toggle to limit rollout risk and unsupported-environment regressions.
- Treat browser support, model bootstrap, and local inference resource limits as first-class UX states rather than hidden implementation details.
- Do not silently bypass backend prompt-policy screening for normal generation. If local mode exists, it must be a visible and explicit user choice or fallback path with clearly reduced safety guarantees relative to the backend path.
- Keep backend and local notebook-identity rules separate:
  - backend generation still requires a synced server-backed notebook id
  - explicit local `WebLLM` mode may run on unsynced local working copies
  - the UI must distinguish these two availability rules clearly

## Out of Scope for This Direction

- Replacing the canonical backend-first AI path
- Automatic provider routing based on prompt length, token estimate, or notebook size
- Automatic provider routing based on any frontend heuristic or silent environment-based switching
- Browser-only production AI as the default product behavior
- Adding a durable notebook `ai` block type, prompt history, or new notebook schema fields
- Changing the backend request/response contract to carry local-provider-specific payloads
- Running notebook code on the backend
- Full local fallback productization across every browser and device class
- Broad multi-model selection UX in the browser
- Non-`JavaScript` generation

## Tasks

### Phase 1: Product and Direction Freeze

## Task 1: `T3/BTF -> RESEARCH: Freeze WebLLM as explicit local mode under backend-first AI`

**Description:** Fix the product and architecture scope for `WebLLM` so the team implements one constrained local mode instead of accidentally creating a second primary AI pathway. This task should resolve the remaining ambiguity between older Sprint 2 `WebLLM` ideas and the now-fixed backend-first Stage 7 architecture.

**Acceptance criteria:**
- [ ] `WebLLM` is explicitly documented as optional local mode and/or retry fallback, not the default path.
- [ ] Automatic provider routing based on prompt size or heuristic branching is explicitly rejected for this direction.
- [ ] The plan explicitly states that local `WebLLM` mode is allowed for unsynced local working copies, while the backend path still requires a synced server-backed notebook.
- [ ] The risk tradeoff relative to backend prompt-policy screening is documented clearly enough for implementation and QA.

**Verification:**
- [ ] Manual cross-check against `docs/ai-architecture.md`, `docs/plans/05-ai-integration-plan.md`, and `docs/sprints/sprint-2/ai-decision-record.md`
- [ ] Review confirms no task in this plan changes the canonical default provider path

**Dependencies:** None

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`
- `docs/sprints/sprint-2/ai-decision-record.md`

**Likely files or areas:**
- `docs/ai-architecture.md`
- `docs/sprints/sprint-2/ai-decision-record.md`
- `docs/plans/06-webllm-local-mode-plan.md`

**Scope:** S

## Task 2: `T3/BTF -> FRONT: Define a shared frontend AI provider abstraction`

**Description:** Introduce a frontend provider abstraction so the existing backend path and the future `WebLLM` path plug into one normalized feature boundary. This task should reduce branching inside the notebook-editor flow and keep provider-specific concerns out of generic block AI UX.

**Acceptance criteria:**
- [ ] A shared frontend provider interface exists for AI generation success, warnings, and normalized error states.
- [ ] The current backend-backed AI flow is migrated onto this abstraction without changing user-visible behavior.
- [ ] The provider result shape includes provider identity so the UI can label `bedrock` vs `webllm`.
- [ ] No backend API contract changes are required to support the abstraction.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Manual review confirms the backend path still calls the existing `generateCodeBlock()` contract

**Dependencies:** `T3/BTF -> RESEARCH: Freeze WebLLM as explicit local mode under backend-first AI`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`

**Likely files or areas:**
- `ui/src/features/ai/api/`
- `ui/src/features/ai/model/`
- `ui/src/features/ai/index.ts`

**Scope:** M

### Phase 2: Local Runtime Foundation

## Task 3: `T3/BTF -> FRONT: Add WebLLM runtime bootstrap and capability checks`

**Description:** Add the frontend runtime logic required to discover whether `WebLLM` is usable in the current browser, lazily bootstrap the model, and surface explicit readiness states. This task should make unsupported environments and heavy model startup cost visible instead of implicit.

**Acceptance criteria:**
- [ ] The frontend can distinguish `unsupported`, `idle`, `loading-model`, `ready`, and `failed` local-provider states.
- [ ] `WebLLM` assets or model loading are lazy and do not start on normal notebook-editor page open.
- [ ] Unsupported browsers or missing capabilities produce stable frontend-local errors rather than silent disabled behavior.
- [ ] Local runtime initialization lives inside frontend AI boundaries, not inside editor-page glue code.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Manual browser checks cover at least one supported-path simulation and one unsupported-path simulation

**Dependencies:** `T3/BTF -> FRONT: Define a shared frontend AI provider abstraction`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`
- `docs/tech_stack.md` if the `WebLLM` library becomes a fixed frontend technology decision

**Likely files or areas:**
- `ui/src/features/ai/model/`
- `ui/src/features/ai/lib/`
- `ui/src/shared/config/`

**Scope:** M

## Task 4: `T3/BTF -> FRONT: Implement the WebLLM generation provider`

**Description:** Implement the actual local provider that runs generation through `WebLLM`, accepts the same normalized frontend provider-abstraction request shape used by the current AI flow, and returns normalized code results compatible with the existing insertion path.

**Acceptance criteria:**
- [ ] The local provider accepts the same normalized frontend provider-abstraction inputs as the backend path, even if it consumes a reduced subset of that context internally.
- [ ] The local provider normalizes output to plain `JavaScript` code plus provider metadata.
- [ ] Local inference failures map to stable frontend-local error codes such as unsupported runtime, bootstrap failure, timeout, and invalid response.
- [ ] The provider does not create a second insertion flow or a second notebook AI state model.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Unit tests cover successful local generation and the main failure classes

**Dependencies:** `T3/BTF -> FRONT: Add WebLLM runtime bootstrap and capability checks`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`
- `docs/ai-test-cases.md`

**Likely files or areas:**
- `ui/src/features/ai/api/`
- `ui/src/features/ai/model/`
- `ui/src/features/ai/lib/`

**Scope:** M

### Phase 3: UX Integration

## Task 5: `T3/BTF -> FRONT: Add explicit local-mode and retry-fallback UI`

**Description:** Integrate `WebLLM` into the existing notebook AI UX as a visible, explicit user choice and as an optional retry path after retryable backend failures. This task should preserve the current source-block interaction model while making provider choice understandable to the user.

**Acceptance criteria:**
- [ ] The UI keeps the local-generation affordance explicit and user-visible, but `Generate locally` stays disabled until the feature flag, runtime policy, and readiness checks allow it.
- [ ] After retryable backend failures such as `AI_PROVIDER_UNAVAILABLE` or `AI_PROVIDER_TIMEOUT`, the UI may offer `Retry locally with WebLLM`.
- [ ] The generated result is clearly labeled as `provider = webllm` and does not appear identical to the backend path in status or messaging.
- [ ] Existing success/error/insertion flows remain unchanged for the canonical backend path.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Manual notebook-editor check confirms explicit provider labeling and retry behavior

**Dependencies:** `T3/BTF -> FRONT: Implement the WebLLM generation provider`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`

**Likely files or areas:**
- `ui/src/features/ai/model/useBlockAiAction.ts`
- `ui/src/features/ai/ui/`
- `ui/src/pages/notebook-editor/`

**Scope:** M

## Task 6: `T3/BTF -> FRONT: Implement local-draft eligibility rules for WebLLM`

**Description:** Decide and implement whether `WebLLM` may run on unsynced local notebooks or only on notebooks that already have a server-backed identity. This task should make the backend prerequisite error and the local-mode availability rule coexist without confusing the notebook UX.

**Acceptance criteria:**
- [ ] The product behavior for `local-*` notebook ids is explicitly defined for local generation mode.
- [ ] The existing backend path still requires a synced server-backed notebook identity.
- [ ] UI messages distinguish backend sync prerequisites from local-mode availability in a way that is understandable to users.
- [ ] Tests cover synced and unsynced notebook cases under the chosen policy.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Manual scenarios cover synced notebook, unsynced notebook, and backend-path-only generation

**Dependencies:** `T3/BTF -> RESEARCH: Freeze WebLLM as explicit local mode under backend-first AI`, `T3/BTF -> FRONT: Add explicit local-mode and retry-fallback UI`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`
- `docs/project.md` if user-visible AI availability changes for unsynced drafts

**Likely files or areas:**
- `ui/src/features/ai/model/useBlockAiAction.ts`
- `ui/src/features/ai/model/types.ts`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

**Scope:** S

### Phase 4: Quality and Rollout Controls

## Task 7: `T3/BTF -> QA: Add WebLLM acceptance coverage`

**Description:** Extend the existing Stage 7 AI acceptance suite so it covers the approved `WebLLM` behavior without creating a second full AI matrix. The scope should stay focused on local-mode enablement, provider distinction, and unchanged notebook insertion semantics.

**Acceptance criteria:**
- [ ] Acceptance coverage exists for supported local success, unsupported browser/runtime, model bootstrap failure, retryable backend failure plus local retry, and provider labeling.
- [ ] The suite confirms that notebook insertion behavior remains identical between backend and local providers.
- [ ] QA artifacts clearly separate backend-contract expectations from frontend-local fallback expectations.
- [ ] No acceptance case implies that `WebLLM` is required for the baseline Stage 7 backend-first slice.

**Verification:**
- [ ] `docs/ai-test-cases.md` is updated with local-mode cases
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Relevant frontend integration tests cover local-mode error and success paths

**Dependencies:** `T3/BTF -> FRONT: Implement local-draft eligibility rules for WebLLM`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-test-cases.md`
- `docs/qa_plan.md`

**Likely files or areas:**
- `docs/ai-test-cases.md`
- `docs/qa_plan.md`
- `ui/src/features/ai/`
- `ui/src/pages/notebook-editor/ui/NotebookEditorPage.test.tsx`

**Scope:** S

## Task 8: `T3/BTF -> FRONT: Add rollout guardrails and feature-flag controls`

**Description:** Add the configuration and rollout controls that keep `WebLLM` optional and reversible in different environments. This task should ensure unsupported browsers, large downloads, or product uncertainty do not force the feature on by accident.

**Acceptance criteria:**
- [ ] `WebLLM` availability is controlled by a frontend feature flag or equivalent runtime configuration.
- [ ] The intended production availability policy is documented: disabled by default, internal-only, or public opt-in.
- [ ] User-facing behavior for disabled local mode is explicit and does not leave dead UI controls.
- [ ] The chosen browser/model support caveats are documented for developers and QA.

**Verification:**
- [ ] `cd ui && pnpm test -- --runInBand`
- [ ] Manual config review confirms `WebLLM` can be disabled without breaking the backend-first flow

**Dependencies:** `T3/BTF -> FRONT: Add explicit local-mode and retry-fallback UI`

**Initial status:** `planned`

**Documentation impact:**
- `docs/ai-architecture.md`
- `docs/tech_stack.md`
- frontend config docs when applicable

**Likely files or areas:**
- `ui/src/shared/config/`
- `ui/src/features/ai/`
- `docs/`

**Scope:** S

## Suggested Delivery Order

1. Freeze the product scope and local-draft policy for `WebLLM`.
2. Introduce the shared frontend provider abstraction.
3. Add runtime bootstrap and capability detection for `WebLLM`.
4. Implement the local generation provider itself.
5. Integrate explicit local-mode and retry-fallback UI.
6. Add rollout controls and acceptance coverage.

## Main Risks

- `WebLLM` may expand from a bounded local-mode enhancement into an accidental second AI product path.
- Browser support, model size, and local hardware limits may create flaky UX unless they are surfaced as explicit states.
- Local mode weakens the single backend policy-enforcement story, so the product must keep it explicit rather than silent.
- If local mode is allowed for unsynced drafts, users may expect parity with the backend path even when safety and audit semantics differ.

## Mitigations

- Keep `WebLLM` opt-in and behind a feature flag.
- Reuse the same prompt derivation, context-builder, and insertion semantics as the backend path.
- Do not introduce automatic provider switching.
- Label provider origin in UI and state.
- Keep acceptance coverage focused on the bounded local-mode behavior rather than general model experimentation.
