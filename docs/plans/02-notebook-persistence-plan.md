# Implementation Plan: Notebook Persistence Backend

## Goal

Implement the Version 1 backend notebook persistence feature so authenticated users can create, list, open, rename, delete, and durably store notebook snapshots through the documented `/api/v1/notebooks` contract.

## Task Artifact

- Current approved task artifact: user request to derive a direction plan from `docs/plans/mvp-roadmap.md` and persist it in this file
- Roadmap source: `docs/plans/mvp-roadmap.md` Stage 3, `Notebook Persistence Backend`
- Canonical backend persistence contract: `api/docs/persistence.md`
- Backend architecture constraints: `api/docs/api_architecture.md`
- Upstream auth dependency plan: `docs/plans/01-auth-backend-plan.md`

## Assumptions

- This plan covers Stage 3 from the roadmap: backend notebook persistence only, not Stage 4 local IndexedDB working-copy persistence and not Stage 6 sync conflict UX.
- The current repository state is still skeletal for notebooks: `api/app/features/notebooks/` is empty and the API v1 router does not yet include notebook routes.
- Authenticated session infrastructure from `01-auth-backend-plan.md` is a hard dependency because all notebook endpoints require a valid backend session cookie.
- The durable storage model stays snapshot-based: one notebook row with a canonical `JSONB` `content_snapshot`, not a multi-table block graph.
- Version 1 notebook CRUD should land before full manual sync so the frontend can move from mock notebook shells toward real server-backed list/open flows.
- Runtime outputs, execution session state, and AI-generated transient data remain outside durable notebook persistence by default.

## Architecture Notes

- Preserve the feature-driven backend structure under `api/app/features/notebooks/{router,schemas,service,repository,models}.py`.
- Keep all notebook routes under `/api/v1/notebooks` and protect them with shared auth dependencies rather than endpoint-local cookie parsing.
- Treat `api/docs/persistence.md` as the implementation-facing source of truth for endpoint shapes, `revision`, `last_synced_at`, and owner-only behavior.
- Keep the server contract aligned with the frontend canonical notebook JSON shape: notebook-level `tags`, ordered `blocks`, allowed block types `text` and `code`, block-level `meta.tags`, and metadata versioning.
- Return `404 Not Found` for notebook IDs not owned by the authenticated user, per `api/docs/persistence.md`, even if some higher-level docs still mention `403`.
- Avoid mixing full sync behavior into early CRUD tasks unless the revision model requires a minimal shared foundation; explicit sync stays a later direction even if the persistence schema prepares for it.
- Reuse the existing integration-test scaffolding in `api/tests/conftest.py`, including the future authenticated client/session pattern established by the auth direction.

## Tasks

### Phase 1: Persistence Foundation

## Task 1: `T3/BTF -> BACK: Add notebook persistence model and migration baseline`

**Description:** Define the durable notebook storage model and Alembic baseline required for owner-scoped notebook entities. This task establishes the `JSONB` snapshot contract, revision fields, timestamps, and ownership relationship that all later notebook APIs depend on.

**Acceptance criteria:**
- [ ] Persistence entities exist for notebooks with `id`, `owner_id`, `title`, `content_snapshot`, `revision`, `created_at`, `updated_at`, and nullable `last_synced_at`, consistent with `api/docs/persistence.md`.
- [ ] The migration baseline creates notebook storage and indexes/constraints appropriate for owner-scoped lookup without introducing a separate block table graph.
- [ ] Shared repository primitives exist for create/get/list/update/delete operations against the notebook row model without losing notebook-level `tags` or block-level `meta.tags` from the stored snapshot.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/test_canary.py -q`
- [ ] Apply Alembic upgrade on the integration database and inspect the resulting notebook table shape.

**Dependencies:** `T3/BTF -> BACK: Add auth persistence model and configuration primitives`

**Likely files or areas:**
- `api/app/features/notebooks/models.py`
- `api/app/features/notebooks/repository.py`
- `api/alembic/versions/`
- `api/docs/persistence.md`

**Scope:** M

## Task 2: `T3/BTF -> BACK: Define notebook schemas and snapshot validation rules`

**Description:** Add request/response schemas and service-level validation for notebook snapshots so backend CRUD works against a fixed Version 1 document shape. This task fixes what the API accepts and returns before endpoint wiring expands.

**Acceptance criteria:**
- [ ] Request and response DTOs exist for notebook summary, full notebook, create payload, patch payload, and shared error responses.
- [ ] Snapshot validation enforces Version 1 rules: structured JSON, notebook-level `tags`, ordered `blocks`, allowed block types `text` and `code`, block-level `meta.tags`, and exclusion of durable runtime outputs by default.
- [ ] Service-level helpers keep duplicated title/id fields consistent where the contract requires notebook row metadata and `content_snapshot` metadata to align.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_validation.py -q`

**Dependencies:** `T3/BTF -> BACK: Add notebook persistence model and migration baseline`

**Likely files or areas:**
- `api/app/features/notebooks/schemas.py`
- `api/app/features/notebooks/service.py`
- `api/tests/integration/notebooks/`
- `api/docs/persistence.md`

**Scope:** M

### Phase 2: CRUD Endpoints

## Task 3: `T3/BTF -> BACK: Implement notebook create and list endpoints`

**Description:** Add authenticated collection endpoints so users can create a notebook and browse only their own notebook summaries. This is the first user-visible notebook persistence slice and should unlock the real notebook list flow for the frontend.

**Acceptance criteria:**
- [ ] `POST /api/v1/notebooks` creates an owned notebook with `revision = 1` and a canonical initial `content_snapshot` that includes `tags: []`.
- [ ] `GET /api/v1/notebooks` returns only notebook summaries for the authenticated user with contract-aligned fields and ordering.
- [ ] Anonymous access returns `401 Unauthorized`, and notebook ownership is enforced through shared auth dependencies rather than ad hoc checks.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_collection.py -q`

**Dependencies:** `T3/BTF -> BACK: Add shared auth session and current-user dependencies`, `T3/BTF -> BACK: Define notebook schemas and snapshot validation rules`

**Likely files or areas:**
- `api/app/features/notebooks/router.py`
- `api/app/features/notebooks/service.py`
- `api/app/features/notebooks/repository.py`
- `api/tests/integration/notebooks/test_collection.py`

**Scope:** M

## Task 4: `T3/BTF -> BACK: Implement notebook retrieval and metadata update endpoints`

**Description:** Add item-level read and rename behavior for owned notebooks so the frontend can open a real persisted notebook and update lightweight metadata without full sync semantics.

**Acceptance criteria:**
- [ ] `GET /api/v1/notebooks/{notebook_id}` returns the full canonical notebook snapshot for an owned notebook, including notebook-level `tags` and block-level `meta.tags`.
- [ ] `PATCH /api/v1/notebooks/{notebook_id}` updates supported metadata such as `title` while keeping row metadata and `content_snapshot` title alignment consistent and without dropping existing tag data from the snapshot.
- [ ] Requests for notebooks outside the current user's ownership return `404 Not Found` per the persistence contract.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_item.py -q`

**Dependencies:** `T3/BTF -> BACK: Implement notebook create and list endpoints`

**Likely files or areas:**
- `api/app/features/notebooks/router.py`
- `api/app/features/notebooks/service.py`
- `api/tests/integration/notebooks/test_item.py`

**Scope:** M

## Task 5: `T3/BTF -> BACK: Implement notebook deletion and route wiring`

**Description:** Complete the CRUD lifecycle with delete behavior and register the notebook router under `/api/v1`. This closes the basic durable notebook lifecycle required before sync-specific work begins.

**Acceptance criteria:**
- [ ] `DELETE /api/v1/notebooks/{notebook_id}` removes or logically deletes owned notebooks according to the chosen implementation and behaves idempotently for inaccessible resources through `404`.
- [ ] The notebook feature router is registered in `api/app/api/v1/router.py` without breaking existing system and health endpoints.
- [ ] The backend exposes a reusable protection pattern for notebook routes based on the shared authenticated-user dependency.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks/test_delete.py -q`
- [ ] `cd api && pytest -m integration tests/integration/system/test_health.py -q`

**Dependencies:** `T3/BTF -> BACK: Implement notebook retrieval and metadata update endpoints`

**Likely files or areas:**
- `api/app/api/v1/router.py`
- `api/app/features/notebooks/router.py`
- `api/app/features/notebooks/service.py`
- `api/tests/integration/notebooks/test_delete.py`

**Scope:** S

### Phase 3: Hardening for Sync Readiness

## Task 6: `T3/BTF -> BACK: Prepare revision semantics and sync-ready notebook responses`

**Description:** Harden the notebook persistence slice so later sync work can build on stable revision and timestamp semantics without revisiting the core CRUD contract. This task does not implement `/sync`, but it makes CRUD responses and storage behavior compatible with the later manual sync direction.

**Acceptance criteria:**
- [ ] Notebook creation and update flows maintain stable `revision`, `updated_at`, and `last_synced_at` semantics consistent with `api/docs/persistence.md`.
- [ ] CRUD responses expose the fields the frontend and later sync feature need, including notebook-level `tags` and block-level `meta.tags`, without leaking runtime-only state into durable notebook records.
- [ ] Repository and service behavior are documented clearly enough that `/api/v1/notebooks/{notebook_id}/sync` can be added as a later task without changing the stored notebook shape.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks -q`

**Dependencies:** `T3/BTF -> BACK: Implement notebook deletion and route wiring`

**Likely files or areas:**
- `api/app/features/notebooks/service.py`
- `api/app/features/notebooks/schemas.py`
- `api/tests/integration/notebooks/`
- `api/docs/persistence.md`

**Scope:** S

## Task 7: `T3/BTF -> BACK: Complete notebook persistence integration coverage and documentation alignment`

**Description:** Finish the notebook persistence direction with regression-oriented integration tests, authenticated fixtures, and documentation cleanup where current docs disagree on access semantics or persistence details.

**Acceptance criteria:**
- [ ] Integration coverage exists for anonymous access, owner-only list/open/update/delete behavior, create defaults including `tags: []`, and notebook JSON validation failure paths including malformed or missing tag fields.
- [ ] Authenticated test fixtures support notebook tests through real or near-real session issuance rather than unauthenticated placeholders.
- [ ] Documentation conflicts relevant to notebook persistence are reconciled, especially owner-only `404` behavior and any persistence field discrepancies related to notebook-level or block-level tags.

**Verification:**
- [ ] `cd api && pytest -q`
- [ ] `cd api && pytest -m integration tests/integration/notebooks -q`

**Dependencies:** `T3/BTF -> BACK: Prepare revision semantics and sync-ready notebook responses`, `T3/BTF -> BACK: Complete auth-focused integration coverage and developer documentation`

**Likely files or areas:**
- `api/tests/conftest.py`
- `api/tests/integration/notebooks/`
- `api/docs/persistence.md`
- `docs/qa_plan.md`

**Scope:** M

## Checkpoints

1. **Checkpoint 1: Persistence foundation is real**
   Notebook tables, migration baseline, and schema validation exist, and the repository no longer depends on an imagined notebook storage model.

2. **Checkpoint 2: Backend notebook CRUD is externally usable**
   Authenticated users can create, list, open, rename, and delete notebooks through real `/api/v1/notebooks` routes, and the frontend can stop relying on mock list data for basic notebook access.

3. **Checkpoint 3: Sync-ready persistence contract is stable**
   Revision-bearing notebook responses and owner-only behavior are covered by tests and aligned with docs, so Stage 6 sync work can start without redesigning storage.

## Risks and Mitigations

- **Risk:** auth groundwork may not be finished when notebook work starts.
  **Mitigation:** keep notebook persistence tasks explicitly dependent on `01-auth-backend-plan.md`, and avoid introducing temporary notebook-specific auth shortcuts.

- **Risk:** higher-level docs currently disagree on owner-only error semantics (`403` vs `404`).
  **Mitigation:** treat `api/docs/persistence.md` as the implementation source of truth and update conflicting docs during hardening.

- **Risk:** the frontend mock editor currently uses in-memory notebook state and may not yet match the backend snapshot schema exactly.
  **Mitigation:** keep validation rules explicit, including `tags`, and surface any schema mismatch early so later frontend integration can adapt before sync work begins.

- **Risk:** CRUD implementation could accidentally absorb sync scope and become too broad.
  **Mitigation:** defer `/sync`, conflict responses, and local-first reconciliation to the later sync direction, while only preserving the fields and revision semantics they require.

- **Risk:** test scaffolding still uses a skipped `authenticated_client`.
  **Mitigation:** sequence notebook integration coverage after auth test fixture completion, and share the same session-issuance pattern across features.

## Open Questions

- Should notebook deletion be hard delete or soft delete in Version 1, given that `api/docs/persistence.md` allows optional `deleted_at`?
- Do list responses need any minimum ordering guarantee beyond stable `updated_at`/recent-first behavior, or should that be fixed now in the contract?
- Should the backend enforce exact equality between the row `title` and `content_snapshot.title` on every write, or only normalize it on create/update endpoints that accept title changes?
- Is a dedicated notebook search/filter slice required in this direction, or should list filtering remain a later frontend integration task once real CRUD is in place?
