# Implementation Plan: Backend Authentication

## Goal

Implement the Version 1 backend authentication feature for the API so the product supports `Email + OTP` sign-in, backend-managed secure `HTTP-only` session cookies, session bootstrap/logout, and Google OAuth within the documented `/api/v1` auth contract.

## Task Artifact

- Current approved task artifact: user request to plan backend authorization work and persist the plan in this file
- Canonical auth contract: `api/docs/auth.md`
- Backend architecture constraints: `api/docs/api_architecture.md`

## Assumptions

- The current repository state is an early backend skeleton: `app/features/auth/` exists only as a placeholder and no auth router is wired yet.
- This plan covers backend auth only; frontend login screens, guards, and client-side auth state are out of scope.
- `Email + OTP` is the primary implementation slice and must land before Google OAuth because both flows share the same session model.
- The backend may use an opaque session identifier or a signed token inside the session cookie, but the external API contract must remain cookie-based.
- `local/dev` may expose `dev_otp` in the OTP request response as allowed by `api/docs/auth.md`; non-dev environments must not.
- Production email provider selection and secret provisioning are integration concerns, not blockers for the initial backend auth feature slice.

## Architecture Notes

- Preserve the feature-driven backend structure: `app/features/auth/{router,schemas,service,repository,models}.py`.
- Keep the API under `/api/v1/auth/*` and do not introduce bearer-token auth or frontend-readable credentials.
- Session validation and notebook access enforcement must remain backend-side.
- Reuse shared modules for config and DB access rather than creating feature-local DB/session infrastructure.
- The current test suite already provides integration scaffolding with `get_db` override support; auth tests should extend that instead of inventing a parallel setup.

## Tasks

### Phase 1: Foundation

## Task 1: `T3/BTF -> BACK: Add auth persistence model and configuration primitives`

**Description:** Define the auth data model, migrations, and configuration required for OTP challenges, backend sessions, and optional OAuth account links. This establishes the storage and settings contract that all later auth flows depend on.

**Acceptance criteria:**
- [ ] Auth persistence entities exist for `users`, `otp_challenges`, and `sessions`, with optional `oauth_accounts` modeled in a way that supports future Google linking.
- [ ] Auth-related settings exist for OTP TTL, session TTL, cookie name/flags, and dev-only OTP exposure without hardcoding environment-specific values in handlers.
- [ ] Alembic migration(s) create the required auth tables and constraints in a form consistent with the documented backend architecture.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/test_canary.py -q`
- [ ] Inspect generated schema via Alembic upgrade on the integration database.

**Dependencies:** None

**Likely files or areas:**
- `api/app/core/config.py`
- `api/app/features/auth/models.py`
- `api/app/features/auth/repository.py`
- `api/alembic/versions/`

**Scope:** M

## Task 2: `T3/BTF -> BACK: Add shared auth session and current-user dependencies`

**Description:** Implement backend-side session parsing, lookup, cookie helpers, and reusable dependencies for retrieving the current authenticated user. This creates the common session layer used by OTP verification, session bootstrap, logout, and future protected notebook endpoints.

**Acceptance criteria:**
- [ ] The backend can read the auth session cookie, resolve an active session, and return an anonymous result when no valid session exists.
- [ ] Reusable dependencies/helpers exist for `current user` and `optional current user` flows without coupling business logic to raw FastAPI request objects.
- [ ] Cookie creation and clearing behavior is centralized so session flags remain consistent across login and logout flows.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth -q`

**Dependencies:** `T3/BTF -> BACK: Add auth persistence model and configuration primitives`

**Likely files or areas:**
- `api/app/core/`
- `api/app/features/auth/service.py`
- `api/app/features/auth/repository.py`
- `api/app/features/auth/schemas.py`

**Scope:** M

### Phase 2: Core Implementation

## Task 3: `T3/BTF -> BACK: Implement email OTP request flow`

**Description:** Add `POST /api/v1/auth/request-otp` with email normalization, validation, challenge creation, throttling hooks, and dev-mode OTP response behavior. This is the first user-visible backend auth capability and should be independently testable before login completion exists.

**Acceptance criteria:**
- [ ] `POST /api/v1/auth/request-otp` accepts a normalized email payload and returns `challenge_id` plus TTL metadata per the contract.
- [ ] Development behavior may include `dev_otp`, while non-dev behavior omits it and routes delivery through the email integration boundary.
- [ ] Invalid payloads and request throttling paths produce stable error semantics suitable for frontend handling.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_request_otp.py -q`

**Dependencies:** `T3/BTF -> BACK: Add auth persistence model and configuration primitives`

**Likely files or areas:**
- `api/app/features/auth/router.py`
- `api/app/features/auth/schemas.py`
- `api/app/features/auth/service.py`
- `api/app/features/auth/repository.py`
- `api/app/integrations/`

**Scope:** M

## Task 4: `T3/BTF -> BACK: Implement OTP verification and session issuance`

**Description:** Add `POST /api/v1/auth/verify-otp` so a valid challenge creates or resolves a user, invalidates the challenge, persists a backend session, and returns the authenticated user summary while setting the secure session cookie.

**Acceptance criteria:**
- [ ] Successful OTP verification creates or reuses the internal user record, invalidates the consumed challenge, and persists an active backend session.
- [ ] The response sets the backend-managed `HTTP-only` session cookie with environment-appropriate flags and returns `user` plus `authenticated_at`.
- [ ] Invalid, expired, consumed, or rate-limited verification attempts produce contract-aligned `401`, `409`, or `429` behavior.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_verify_otp.py -q`

**Dependencies:** `T3/BTF -> BACK: Add shared auth session and current-user dependencies`, `T3/BTF -> BACK: Implement email OTP request flow`

**Likely files or areas:**
- `api/app/features/auth/router.py`
- `api/app/features/auth/service.py`
- `api/app/features/auth/repository.py`
- `api/app/features/auth/models.py`

**Scope:** M

## Task 5: `T3/BTF -> BACK: Implement session bootstrap and logout endpoints`

**Description:** Add `GET /api/v1/auth/session` and `POST /api/v1/auth/logout` so the frontend can bootstrap auth state from the backend and terminate sessions cleanly without inspecting cookie contents.

**Acceptance criteria:**
- [ ] `GET /api/v1/auth/session` returns `{authenticated: false, user: null}` for anonymous requests and the documented user summary for valid sessions.
- [ ] `POST /api/v1/auth/logout` invalidates the current session server-side and clears the auth cookie in the response.
- [ ] Repeated anonymous session checks and logout requests behave safely and predictably without leaking internal state.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_session.py -q`

**Dependencies:** `T3/BTF -> BACK: Implement OTP verification and session issuance`

**Likely files or areas:**
- `api/app/features/auth/router.py`
- `api/app/features/auth/service.py`
- `api/app/features/auth/schemas.py`

**Scope:** S

## Task 6: `T3/BTF -> BACK: Wire auth router and protect downstream feature boundaries`

**Description:** Register the auth feature router under `/api/v1/auth`, expose the canonical endpoints, and introduce the backend-side auth dependency pattern that downstream features such as notebooks can adopt for private-by-default access.

**Acceptance criteria:**
- [ ] The API router includes the auth feature router under the documented `/api/v1/auth` prefix.
- [ ] Auth route registration does not break existing `/api/v1/health` and `/api/v1/system/health` behavior.
- [ ] A documented and reusable protection pattern exists for future notebook routes to require a valid backend session.

**Verification:**
- [ ] `cd api && pytest tests/integration/system/test_health.py -q`
- [ ] `cd api && pytest -m integration tests/integration/auth -q`

**Dependencies:** `T3/BTF -> BACK: Implement session bootstrap and logout endpoints`

**Likely files or areas:**
- `api/app/api/v1/router.py`
- `api/app/features/auth/router.py`
- `api/app/features/notebooks/`

**Scope:** S

### Phase 3: Extended Flow and Quality

## Task 7: `T3/BTF -> BACK: Implement Google OAuth start and callback flow`

**Description:** Add the optional-but-required-for-V1 Google OAuth flow on top of the shared session model. This task should focus on provider start/callback handling, account linking, controlled error outcomes, and reuse of the same backend-managed session issuance used by OTP auth.

**Acceptance criteria:**
- [ ] `GET /api/v1/auth/google/start` initiates the provider redirect with state handling owned by the backend.
- [ ] `GET /api/v1/auth/google/callback` validates the provider response, creates or links the internal user, and establishes the same backend session model as OTP verification.
- [ ] Provider denial, invalid state, and callback failures resolve through controlled auth errors rather than unhandled exceptions.

**Verification:**
- [ ] `cd api && pytest tests/unit -q`
- [ ] `cd api && pytest -m integration tests/integration/auth/test_google_oauth.py -q`

**Dependencies:** `T3/BTF -> BACK: Implement session bootstrap and logout endpoints`

**Likely files or areas:**
- `api/app/features/auth/router.py`
- `api/app/features/auth/service.py`
- `api/app/features/auth/repository.py`
- `api/app/integrations/`

**Scope:** M

## Task 8: `T3/BTF -> BACK: Complete auth-focused integration coverage and developer documentation`

**Description:** Finish the backend auth slice with regression-oriented tests, authenticated test fixtures, and minimal implementation-facing documentation updates so future notebook and UI work can depend on stable auth behavior.

**Acceptance criteria:**
- [ ] Integration coverage exists for OTP request, OTP verification, session bootstrap, logout, and Google OAuth success/error paths.
- [ ] The current `authenticated_client` test stub is replaced or augmented with real session issuance suitable for downstream protected-feature tests.
- [ ] Any implementation deviations from `api/docs/auth.md` discovered during delivery are reconciled by code changes or explicit documentation updates.

**Verification:**
- [ ] `cd api && pytest -q`
- [ ] `cd api && pytest -m integration -q`

**Dependencies:** `T3/BTF -> BACK: Implement Google OAuth start and callback flow`, `T3/BTF -> BACK: Wire auth router and protect downstream feature boundaries`

**Likely files or areas:**
- `api/tests/conftest.py`
- `api/tests/integration/auth/`
- `api/docs/auth.md`
- `api/docs/api_architecture.md`

**Scope:** M

## Risks and Open Points

- The repository does not yet expose existing Alembic auth migrations in the inspected context; table naming and migration baselining may need confirmation before implementation starts.
- Cookie behavior across local HTTPS, proxy headers, and non-dev environments must be validated carefully because the architecture requires secure `HTTP-only` cookies.
- Google OAuth callback URLs and environment-specific secrets are likely to be the highest integration-risk part of the feature.
- If notebook endpoints land in parallel, they should consume the shared auth dependency rather than implementing a separate access check path.
