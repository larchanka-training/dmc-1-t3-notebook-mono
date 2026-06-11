# API and UI Testing Strategy

This document is based on [project.md](./project.md) (product model, Version 1 functional and non-functional requirements), [system_architecture.md](./system_architecture.md) (flows, component boundaries, fixed V1 decisions), [tech_stack.md](./tech_stack.md) (stack and local domains), and the monorepo infrastructure (`docker-compose.yaml`, reverse proxy in `proxy/` for `notebook.com` / `api.notebook.com` / `pgadmin.notebook.com`).

The `api/` and `ui/` repositories are included as git submodules (`git submodule update --init --recursive` when directories are empty). Detailed endpoint and screen implementation lives in those repositories; below is product- and integration-level strategy. The `e2e/` package scaffold and CI run contract are described in [tasks.md](../tasks.md).

> Russian companion: [qa_planRU.md](./qa_planRU.md)

---

## 1. Goals and scope

**Goal:** ensure users can complete the success scenarios from section 15 of [project.md](./project.md) and that backend ↔ frontend contracts, code execution security, and offline mode do not regress.

**Version 1 focus:**

- authentication (`Email + OTP`, `Google OAuth`) and notebooks private by default;
- notebook CRUD, list, search/filtering (minimum);
- block editor (`text` with Markdown, `code` with JavaScript), ordering, deletion;
- code execution: single block, all blocks, from selected block downward;
- shared `execution session` and output bound to a block;
- outputs: `text`, `object`, `table`, `chart`, `error` (runtime artifacts; by default not part of durable notebook state);
- IndexedDB, operation without backend, explicit sync without automatic merge on conflict;
- export to portable notebook JSON;
- AI: prompt → code → edit prompt → regeneration → confirm/edit → execution.

**Out of scope for V1 test design:** real-time collaborative editing, Python/multi-language kernels, LSP, plugins, and other items from section 9 of [project.md](./project.md).

---

## 2. Principles and test pyramid

| Level | Purpose | Where to place (guideline) |
|-------|---------|----------------------------|
| Unit | Pure logic: block order, sync-state merge, export serialization, DTO validation | `api` (services, use cases), `ui` (stores, reducers, utilities without DOM) |
| API integration | HTTP + DB + Alembic migrations, per-user access policies | `api` (FastAPI test client, transactional/test DB) |
| Contract / consumer | Request/response schema alignment with the frontend | OpenAPI from FastAPI + client tests or Pact-like checks |
| UI integration | Components with real router/state, without a full browser | `ui` (`Vitest` + Testing Library — see [tech_stack.md](./tech_stack.md)) |
| E2E (end-to-end) | Critical user flows over HTTPS and real domains | `e2e/` package (`Playwright`; tags `@smoke`, `@blocks`, `@exec`, `@offline`, `@export`, `@ai`) |

Rule: expensive E2E covers a **narrow set** of happy paths and a few degradations; breadth is covered by API and unit tests.

### Test types for issues

In the bug template (`.github/ISSUE_TEMPLATE/bug_report.yml`), the “Test types” checkboxes define the **minimum runs required before closing the ticket**. Check only what the bug area actually needs.

| Issue item | When to check |
|------------|---------------|
| **Unit tests** | Pure logic changed (utilities, reducers, validation, sync merge, etc.) — add a test for the fix or regression. |
| **API integration** | HTTP, DB, migrations, 401/403 responses, or endpoint contract affected. |
| **UI integration** | Components, routing, or client state affected without needing a full browser. |
| **E2E** | Bug appears only in a full user flow (domains, cookies, network, multiple screens). |
| **Regression** | High risk of side effects in adjacent V1 scenarios — explicit area pass after the fix. |

If manual verification per issue steps is enough without automated tests — do not check unit/API/UI/E2E; leave only **Regression** if needed, or check nothing and document scope in Acceptance Criteria.

---

## 3. Environments and data

| Environment | Purpose |
|-------------|---------|
| Local `docker-compose` | API `:8000`, UI `:3000`→`5173`, Postgres `:5432`, pgAdmin `:5050`, proxy `:8080` (HTTP) / `:8443` (HTTPS) on `notebook.com`, `api.notebook.com`, `pgadmin.notebook.com` (see `proxy/nginx.conf`, [Local-Proxy.md](./Local-Proxy.md)) |
| Direct access without proxy | `http://localhost:3000` (UI), `http://localhost:8000` (API) — for debugging; E2E and auth scenarios preferably via HTTPS and domains |
| CI | Same services; `E2E_BASE_URL` (default `https://notebook.com:8443` or agreed stand URL); `ignoreHTTPSErrors` for self-signed certificate; for cookie/SameSite — same scheme context as local development through proxy |

**Test data:** user fixtures, empty and populated notebooks, `text` (Markdown) and `code` (JS) blocks, long document for performance. For auth in CI — test doubles: fixed OTP, separate OAuth test application or callback stub; do not use production secrets or real email.

---

## 4. API testing strategy

Repository stack: **FastAPI**, **PostgreSQL**, **Alembic**. Coverage areas below align with entities in [project.md](./project.md) (section 13) and [system_architecture.md](./system_architecture.md).

### 4.1 Authentication and sessions

- **Email + OTP:** OTP request, delivery (mock external email service), successful verification, invalid/expired OTP, repeat request.
- **Google OAuth:** flow start, callback, user creation/linking, provider denial/error.
- After successful login — backend-managed secure **`HTTP-only` session cookie** (not bearer token in `localStorage`); access without cookie → 401; another user’s notebook → 403 (private by default).
- Session expiry: boundary values for `SESSION_TTL_SECONDS` (and `TOKEN_TTL_SECONDS` if a separate layer exists) from env.
- Proxy: correct `X-Forwarded-*` headers, operation behind HTTPS on `:8443` (impact on `Secure` cookie).

### 4.2 Notebook (CRUD and list)

- Create, read, rename, delete; list only own notebooks.
- Search/filtering (minimum scope FR 10.1): case insensitivity, empty result, special characters.

### 4.3 Blocks and content

- Create/update blocks with types `text` (Markdown content) and `code` (JavaScript); order (`order` or equivalent).
- Block deletion; reorder remaining blocks.
- Validation: empty content, oversized payload (API limits), invalid block type.

### 4.4 Synchronization (SyncState)

- Explicit sync: successful write to server; idempotency of repeat sync with the same body.
- **Conflict:** when local and server copies diverge, backend returns conflict **without automatic merge**; UI shows explicit state and waits for user decision (not a “silently take newer version” scenario).
- Recovery after network drop: retry sync request; unsynced local edits remain in IndexedDB until successful sync.
- Sync metadata matches DB state after a successful operation.

### 4.5 AI broker (backend-mediated)

- Successful code generation/refinement for selected block; external LLM timeout/5xx → predictable error for UI.
- Response treated as **untrusted**: not executed on server; after insertion on frontend — normal editable block content.

### 4.6 API non-functional aspects

- **Security:** no SQL injection (parameterized queries), rate limiting (if added), no internal error leakage in responses; LLM and OAuth credentials only on backend.
- **Reliability:** transactions on bulk block updates; rollback on error.
- **Performance:** list and large notebook open response time (budgets to be agreed by the team).

**Tools:** `httpx.AsyncClient` / `TestClient`, factories via pytest, DB — separate schema or transactions with rollback; if available — OpenAPI snapshot for schema regression.

---

## 5. UI testing strategy

Repository stack: **React**, **TypeScript**, **Vite**. Critical areas: **vertical block flow**, **IndexedDB**, **manual sync**, **client-side execution orchestrator**, and **runtime isolation** (Web Worker / iframe / sandbox — confirm in `ui`).

### 5.1 Unit and component tests

- Render `text` and `code` block types; collapse/expand.
- Editor: input, draft save to local state, switch blocks without losing unsaved content (if intended).
- Sync indicators: “offline”, “unsynced changes”, sync success, **explicit conflict** (no silent merge).
- Auth UI: email/OTP form, Google OAuth redirect (network mocks via MSW).

### 5.2 E2E (Playwright)

Run against `https://notebook.com:8443` (after `hosts`, `docker compose`, and trusting the self-signed certificate) or CI equivalent with `E2E_BASE_URL` and `ignoreHTTPSErrors: true`.

**Required scenarios (traceability → FR 8, 10, 15):**

1. Login (**Email + OTP** or **Google OAuth** — at least one method in smoke, both in full suite) → notebook list → create → open.
2. Add `text` (Markdown) and `code` blocks; move up/down; delete.
3. Run one code block; run “all”; run “from current downward”; verify variables from previous block are visible in the next (`execution session`).
4. Outputs: `text`, `object` (JSON-like display), `table`, `chart`, **`error`** — structural/visual DOM check; after page reload, outputs need not restore from durable state (re-run if needed).
5. Offline: disable network (`page.context().setOffline(true)` / `route.abort`) → edits persist in IndexedDB → restore network → **manual** sync → data on server (verify via API or re-login).
6. **Sync conflict:** two divergent copies → explicit conflict state, no automatic merge.
7. Export: downloaded **portable notebook JSON** with expected structure (metadata + blocks; execution output snapshots not required).
8. AI: description → generation → edit prompt → regeneration → **confirm/edit insertion** → code runs.

**UX regressions:** editor focus traps, scroll to output after run, long execution (spinner/cancel if present).

### 5.3 User code execution specifics

- Negative scenarios: infinite loop, `throw`, heavy loop — `error` output type, user message, tab does not hang (worker timeout where applicable).
- **Isolation:** attempts to access `parent`, app `localStorage`, `fetch` to internal API with session cookie — expected restriction per security model (document expected behavior in test case after reviewing runtime implementation).

### 5.4 Stage 5 acceptance checklist

Use this checklist after Stage 5 runtime slices land to verify the notebook execution MVP as one coherent flow:

1. `run current`: execute a single `code` block and verify output binds only to that block.
2. Session reuse: execute an upper `code` block that declares shared state, then execute a lower `code` block and verify the state is still available without reset.
3. `run from current downward`: start from a selected `code` block in a mixed notebook and verify only lower `code` blocks execute in notebook order while `text` blocks are skipped.
4. `run all`: execute after a previous single-block run and verify the worker session resets before the full top-to-bottom code range starts.
5. `stop`: start a long-running block, invoke stop, verify the UI shows `stopping` then `canceled`, and verify the next run starts from a clean worker session.
6. Error and timeout UX: verify syntax/runtime error and timeout cases surface as user-visible runtime states and bound error outputs.
7. Output rendering: verify `text`, `object`, `table`, and `error` outputs render next to the originating `code` block.
8. Non-durable outputs: reload the page and verify runtime outputs do not reappear as part of durable notebook content before a new run.

---

## 6. End-to-end “API + UI” scenarios

| ID | Scenario | API check | UI check |
|----|----------|-----------|----------|
| X1 | New notebook | POST notebook, GET by id | List updated, document opens |
| X2 | Offline editing | — | Changes in IndexedDB |
| X3 | Sync after offline | Sync endpoint, 200 | “Synchronized” indicator |
| X4 | Privacy | GET another user’s id → 403 | “No access” message / redirect |
| X5 | Sync conflict | Conflict response, no merge on server | Explicit conflict state, user action |
| X6 | Email OTP login | OTP issue/verify, Set-Cookie session | Authorized state, access to own notebooks |
| X7 | Google OAuth login | OAuth callback, Set-Cookie session | Authorized state |

---

## 7. Non-functional testing (cross-cutting)

- **Performance:** time to interactive for list and editor; run-all time on N blocks (threshold to agree).
- **Reliability:** close tab with unsaved local state — notebook content restored after reopen; execution outputs — only after re-run unless cached locally separately.
- **Accessibility (a11y):** basic roles for Run/Sync buttons, labels on error and conflict indicators.
- **Security:** see 4.6 and 5.3; when CSP appears — verify no regressions for worker/iframe.

---

## 8. Release readiness criteria (QA exit)

- All scenarios in section 5.2 pass on the reference environment (`docker-compose` + proxy + hosts).
- No open blockers on sync, conflicts, or data loss on network interruption.
- API: smoke + critical integration test set green in CI.
- Both login methods (OTP and Google) verified at least in smoke scope.
- Known limitations documented (self-signed SSL, port `:8443` for local HTTPS).

---

## 9. Reporting and metrics

- Link cases to [project.md](./project.md) requirements and [system_architecture.md](./system_architecture.md) flows (traceability table or TMS / Playwright `@` tags).
- Defects: split “API”, “UI”, “integration/infra”.
- Periodic pyramid review: E2E growth without unit growth — signal to refactor for testability.

---

## 10. Next steps for the team

1. Ensure `api` and `ui` submodules are initialized; capture current OpenAPI and routes.
2. Complete infrastructure tasks from [tasks.md](../tasks.md) (pytest, Vitest, Playwright `e2e/`).
3. Add minimal **smoke suite** to CI: API health + `e2e:smoke` (canary + login → create notebook when UI is ready).
4. Agree response-time and document-size budgets for performance checks.
5. Align [Local-Proxy.md](./Local-Proxy.md) with `proxy/nginx.conf` (`notebook.com` domains, ports `8080`/`8443`).
