# QA-64 — Implement E2E Test Automation with Playwright

## Context

This specification defines the implementation work required to create the `e2e/` package — an independent, zero-configuration-on-first-run end-to-end test automation layer for the JS Notebook monorepo using Playwright.

The package must work identically in two environments:

| Environment | UI base URL | API base URL | Certificate |
|---|---|---|---|
| **Local** (`docker-compose` + reverse proxy) | `https://notebook.com:8443` | `https://api.notebook.com:8443` | Self-signed; `ignoreHTTPSErrors: true` |
| **AWS / CI** | `E2E_BASE_URL` env value | `E2E_API_BASE_URL` env value | Depends on deployment; same flag |

Reference documents:

- [`docs/qa_plan.md`](../qa_plan.md) — §3 (environments and test data), §5.2 (E2E required scenarios), §10 (next steps)
- [`docs/system_architecture.md`](../system_architecture.md) — §3 (V1 fixed decisions), §8.6–8.7 (auth flows), §9.1 (security constraints)
- [`docs/tech_stack.md`](../tech_stack.md) — §3 (frontend stack, `Playwright 1.54`)
- [`proxy/nginx.conf`](../../proxy/nginx.conf) — upstream topology, ports `:8080` / `:8443`, domains

---

## 1. Goals

1. Stand up the Playwright infrastructure against the existing local `docker-compose` stack and reverse proxy (`notebook.com`, `api.notebook.com`, ports `:8080` / `:8443`) so that the first real scenario can be written as a single file in `e2e/tests/`.
2. Pre-run setup (compose, `hosts` entries, certificate trust) is documented once in `e2e/README.md`; each subsequent run requires only `E2E_BASE_URL` and auth env vars.
3. A stable smoke canary runs against the live stack and proves the infrastructure is wired correctly before any business-logic tests are added.

---

## 2. Out of Scope

- Auth, notebook CRUD, block editor, execution, offline/sync, AI, export E2E tests — these are future tasks referenced in `docs/qa_plan.md §5.2`; only their fixture stubs and TODO comments are part of this issue.
- Changes to `ui/`, `api/`, or `proxy/`.
- CI pipeline changes (a follow-up issue).

---

## 3. Package Structure

Create a new top-level directory `e2e/` as a standalone package in the monorepo. It must **not** be nested inside `ui/` or `api/`.

```
e2e/
├── package.json
├── tsconfig.json
├── playwright.config.ts
├── README.md
├── .env.example          # documents env vars; copy to e2e/.env for non-default runs
├── fixtures/
│   └── base.ts
├── tests/
│   └── canary.spec.ts
├── utils/
│   └── .gitkeep
├── test-results/          # Playwright test artifacts (gitignored)
├── playwright-report/     # HTML report (gitignored)
└── reports/
    └── junit-e2e.xml      # JUnit XML output (gitignored, created at runtime)
```

Add the following entries to the root `.gitignore` (or `e2e/.gitignore` if the root already exists):

```
e2e/node_modules/
e2e/test-results/
e2e/playwright-report/
e2e/reports/
e2e/.env
```

`e2e/.env.example` is committed (no secrets) so a developer can `cp .env.example .env` and only edit values when running against a non-default environment.

---

## 4. `e2e/package.json`

```json
{
  "name": "e2e",
  "private": true,
  "version": "0.1.0",
  "scripts": {
    "e2e": "playwright test --pass-with-no-tests",
    "e2e:smoke": "playwright test --grep @smoke --pass-with-no-tests",
    "e2e:install": "npx playwright install --with-deps chromium",
    "e2e:report": "playwright show-report playwright-report"
  },
  "devDependencies": {
    "@playwright/test": "^1.54.2",
    "typescript": "^5.6.3"
  }
}
```

Notes:

- `e2e:install` must be the **only** setup step a developer needs before the first run after cloning.
- No production dependencies.
- Version pins must match `@playwright/test` version used in `ui/package.json` (`^1.54.2`).
- `--pass-with-no-tests` is mandatory: by default `playwright test` exits `1` when no tests match. The flag keeps the run green after the canary is removed (Definition of Done #4) and when `--grep @smoke` matches nothing.
- `--grep @smoke` matches the Playwright `tag` annotation on tests (see §8), not just the test title.
- `e2e:report` opens the last HTML report locally; CI consumes `reports/junit-e2e.xml` instead.

---

## 5. `e2e/tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist"
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules", "dist"]
}
```

---

## 6. `e2e/playwright.config.ts`

All configuration must be driven from environment variables with safe local defaults so that no file editing is required to run against either the local stack or a remote environment.

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,

  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'https://notebook.com:8443',
    ignoreHTTPSErrors: true,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Forward-looking convention so future tests can use page.getByTestId().
    // Confirm the exact attribute used by ui/ components when the auth UI lands.
    testIdAttribute: 'data-testid',
  },

  reporter: [
    ['list'],
    ['junit', { outputFile: './reports/junit-e2e.xml' }],
    ['html', { outputFolder: './playwright-report', open: 'never' }],
  ],

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
```

### Configuration requirements

| Key | Value / Source | Reason |
|---|---|---|
| `baseURL` | `E2E_BASE_URL` env, default `https://notebook.com:8443` | Maps to reverse-proxy HTTPS listener (see `proxy/nginx.conf`) |
| `ignoreHTTPSErrors` | `true` (always) | Self-signed certificate in local and CI stacks |
| `trace` | `'on-first-retry'` | Produces `trace.zip` on first retry; artifact stored in `test-results/` |
| `screenshot` | `'only-on-failure'` | Stored in `test-results/` alongside trace |
| `video` | `'retain-on-failure'` | Stored in `test-results/` on failure |
| `reporter` | `list` + `junit` + `html` | `list` for console, `junit` for CI, `html` for local review |
| JUnit output | `./reports/junit-e2e.xml` | Consistent with `api/reports/` naming convention |
| HTML report | `./playwright-report/` | Gitignored; opened manually with `npx playwright show-report` |
| Projects | `chromium` only | V1 scope; other browsers deferred |
| `fullyParallel` | `false` | Auth-dependent tests share session state; safe default |
| `workers` | `1` | Prevents race conditions with shared local stack |

---

## 7. `e2e/fixtures/base.ts`

Extend the Playwright `test` object with two fixtures: `authenticatedPage` and `apiClient`. These are stubs in this issue — the implementation bodies are left as TODOs with links to the required E2E scenarios from `docs/qa_plan.md §5.2`.

```ts
import { test as base, expect, type Page, type APIRequestContext } from '@playwright/test';

// Env with local defaults — see e2e/README.md for full list
const API_BASE_URL = process.env.E2E_API_BASE_URL ?? 'https://api.notebook.com:8443';
const TEST_USER_EMAIL = process.env.E2E_TEST_USER_EMAIL ?? '';
const TEST_OTP = process.env.E2E_TEST_OTP ?? '';
const GOOGLE_AUTH_ENABLED = process.env.E2E_GOOGLE_AUTH_ENABLED === 'true';

type Fixtures = {
  authenticatedPage: Page;
  apiClient: APIRequestContext;
};

export const test = base.extend<Fixtures>({
  /**
   * authenticatedPage
   *
   * Provides a Page with an active authenticated session.
   * Authentication is established via Email + OTP (system_architecture.md §8.6) using
   * E2E_TEST_USER_EMAIL and E2E_TEST_OTP env vars. The session is stored in an
   * HTTP-only session cookie managed by the backend (system_architecture.md §3 decision 9).
   *
   * TODO (QA-64 follow-up): implement OTP login flow once the auth UI is stable.
   *   Required E2E scenario: qa_plan.md §5.2 scenario 1 — login → notebook list → create → open.
   *   Steps:
   *     1. POST /api/v1/auth/otp/request with TEST_USER_EMAIL
   *     2. POST /api/v1/auth/otp/verify with TEST_OTP
   *     3. Assert HTTP-only session cookie is set
   *     4. Return page in authenticated state
   *
   * TODO (QA-64 follow-up): add Google OAuth path.
   *   Required E2E scenario: qa_plan.md §5.2 scenario 1 (Google OAuth branch).
   *   Skip when E2E_GOOGLE_AUTH_ENABLED is false (see test.skip usage below).
   */
  authenticatedPage: async ({ page }, use) => {
    // TODO: implement — see comments above
    await use(page);
  },

  /**
   * apiClient
   *
   * Provides an APIRequestContext scoped to E2E_API_BASE_URL.
   * Cookies from the browser context are forwarded so the API client reuses the
   * same authenticated session as the page (system_architecture.md §8.6–8.7).
   *
   * TODO (QA-64 follow-up): forward session cookie from browser context once
   * authenticatedPage is implemented.
   *   Used by: qa_plan.md §5.2 scenarios 5 (offline sync verification via API),
   *             6 (conflict — verify no server-side merge), 7 (export structure check).
   */
  apiClient: async ({ playwright, context }, use) => {
    const cookies = await context.cookies();
    const apiContext = await playwright.request.newContext({
      baseURL: API_BASE_URL,
      ignoreHTTPSErrors: true,
      extraHTTPHeaders: {
        Cookie: cookies.map((c) => `${c.name}=${c.value}`).join('; '),
      },
    });
    await use(apiContext);
    await apiContext.dispose();
  },
});

// Re-export expect so tests import only from this file
export { expect };

/**
 * Helper: skip a test when Google OAuth is not available in the current environment.
 * Usage:  skipIfGoogleAuthDisabled();
 *
 * TODO (QA-64 follow-up): apply to all tests tagged @auth that exercise the Google flow.
 *   Reference: qa_plan.md §5.2 scenario 1 (Google OAuth branch), §3 (test doubles).
 */
export function skipIfGoogleAuthDisabled() {
  if (!GOOGLE_AUTH_ENABLED) {
    test.skip(true, 'E2E_GOOGLE_AUTH_ENABLED is not true — Google OAuth tests skipped');
  }
}
```

---

## 8. `e2e/tests/canary.spec.ts`

The canary is the only test implemented in this issue. It must:

- Be tagged `@smoke` using Playwright's `tag` annotation (filterable via `--grep @smoke`), not a tag embedded in the title string.
- Open `baseURL` (the UI entry point behind the reverse proxy).
- Assert the HTTP response is `200` **or** a redirect to the login page (both are valid — the app may redirect unauthenticated users).
- Assert `document.title` is non-empty.
- Not perform any auth, API, or business-logic assertions.

```ts
import { test, expect } from '../fixtures/base';

test(
  'canary — UI is reachable and returns a page title',
  { tag: '@smoke' },
  async ({ page }) => {
    // page.goto follows redirects. For an unauthenticated SPA the proxy returns the
    // app shell (200) and any redirect to /login happens client-side. A server-side
    // redirect to a login page is also acceptable — both stay below 400.
    const response = await page.goto('/');
    expect(
      response?.status(),
      'UI entry point should respond without an HTTP error',
    ).toBeLessThan(400);

    const title = await page.title();
    expect(title.trim().length, 'document.title should not be empty').toBeGreaterThan(0);
  },
);
```

---

## 9. Environment Variables

All env vars must have safe local defaults. No `.env` file is required for a first `e2e:smoke` run against the local stack.

| Variable | Default | Purpose |
|---|---|---|
| `E2E_BASE_URL` | `https://notebook.com:8443` | UI entry point (reverse proxy HTTPS) |
| `E2E_API_BASE_URL` | `https://api.notebook.com:8443` | API base URL (reverse proxy HTTPS) |
| `E2E_TEST_USER_EMAIL` | *(empty)* | Email address used in OTP login flow for authenticated tests |
| `E2E_TEST_OTP` | *(empty)* | Fixed OTP for test/staging environments (never used in production; see `docs/qa_plan.md §3`) |
| `E2E_GOOGLE_AUTH_ENABLED` | `false` | Set to `true` to enable Google OAuth test paths; requires a test OAuth application or callback stub |

Store values for non-default environments in a local `.env` file at `e2e/.env` (gitignored). A committed `e2e/.env.example` documents every variable (no secrets); copy it to start:

```bash
cp e2e/.env.example e2e/.env
```

Load with `dotenv` if needed in the future, or pass inline:

```bash
E2E_BASE_URL=https://notebook.com:8443 npm run e2e:smoke
```

Suggested `e2e/.env.example` contents:

```bash
# UI entry point (reverse-proxy HTTPS). Default works against local docker-compose.
E2E_BASE_URL=https://notebook.com:8443
# API base URL (reverse-proxy HTTPS).
E2E_API_BASE_URL=https://api.notebook.com:8443
# Email + OTP login (test/staging only — never production secrets).
E2E_TEST_USER_EMAIL=
E2E_TEST_OTP=
# Enable Google OAuth tests (requires a test OAuth app or callback stub).
E2E_GOOGLE_AUTH_ENABLED=false
```

---

## 10. `e2e/README.md` — Required Content

The README must cover the following sections exactly. Content may be prose or structured lists.

### 10.1 Prerequisites (one-time setup per machine)

1. **Docker / Docker Compose** — install if not present.
2. **`hosts` entries** — add to `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):
   ```
   127.0.0.1 notebook.com
   127.0.0.1 api.notebook.com
   ```
3. **Browser certificate trust** (optional but removes browser warnings) — see `docs/Local-Proxy.md` for `mkcert` instructions; E2E tests bypass the warning via `ignoreHTTPSErrors: true` and do not require manual trust.
4. **Playwright browsers** — run once after cloning:
```bash
cd e2e
# Preferred: uses the package script which installs required browser binaries
npm run e2e:install
# Fallback (works if the script fails or you prefer explicit install):
npx playwright install chromium
```

### 10.2 Starting the stack

```bash
# From the monorepo root
./start-services.sh
# Or manually:
docker compose up -d
```

The reverse proxy listens on:
- `:8080` — HTTP (`notebook.com`, `api.notebook.com`)
- `:8443` — HTTPS (`notebook.com`, `api.notebook.com`)

E2E tests use `:8443` (HTTPS) as the canonical base.

### 10.3 Running tests

```bash
cd e2e

# Full suite
npm run e2e

# Smoke suite only (canary + future @smoke-tagged tests)
npm run e2e:smoke

# With a custom base URL
E2E_BASE_URL=https://notebook.com:8443 npm run e2e:smoke

# Open the HTML report from the last run
npm run e2e:report
```

### 10.4 Environment variables

Full table — same as §9 above. Reference for CI: pass all vars as environment secrets; no `.env` file is required if all vars have acceptable defaults.

### 10.5 Artifacts

After a run (especially on failure):

| Artifact | Location | How to view |
|---|---|---|
| Trace (`.zip`) | `e2e/test-results/<test-name>/trace.zip` | `npx playwright show-trace e2e/test-results/.../trace.zip` |
| Screenshot (`.png`) | `e2e/test-results/<test-name>/` | Open directly |
| Video (`.webm`) | `e2e/test-results/<test-name>/` | Open directly |
| JUnit XML | `e2e/reports/junit-e2e.xml` | Import into CI / test reporter |
| HTML report | `e2e/playwright-report/` | `npx playwright show-report e2e/playwright-report` |

### 10.6 Tag convention

Tags align with `docs/qa_plan.md §5.2`. All tags are fixed here to ensure future tests land in the correct suite from day one.

| Tag | Suite / scenario |
|---|---|
| `@smoke` | Canary + minimal login + notebook open — must be green before merge |
| `@auth` | Login flows (Email OTP, Google OAuth); skip Google with `E2E_GOOGLE_AUTH_ENABLED=false` |
| `@blocks` | Block creation, editing, reordering, deletion |
| `@exec` | Code execution: single block, all, from current; output types; execution session |
| `@offline` | Offline editing (IndexedDB), network restore, manual sync |
| `@sync` | Sync state indicators, explicit conflict (no automatic merge) |
| `@export` | Portable notebook JSON download and structure check |
| `@ai` | AI prompt → code generation → confirm → execution |

A test may carry multiple tags: `test('@smoke @auth login via OTP', ...)`.

### 10.7 Future scenarios

For required E2E scenarios and their acceptance criteria, see `docs/qa_plan.md §5.2`. Each future test file should import `{ test, expect }` from `../fixtures/base` and apply the matching tag from §10.6.

---

## 11. Definition of Done

All items below must be true before the issue can be closed.

| # | Criterion | How to verify |
|---|---|---|
| 1 | `npm run e2e:install` completes without errors on a clean clone | Run in a fresh `e2e/` directory after `npm ci` |
| 2 | `npm run e2e:smoke` is **green 5 times consecutively** against the running `docker-compose` stack with `E2E_BASE_URL=https://notebook.com:8443` | Run `for i in {1..5}; do npm run e2e:smoke || break; done` |
| 3 | On artificial canary failure, `e2e/test-results/` contains a `.png` screenshot and a `.webm` video on the **first** failure, and a `trace.zip` once the run is **retried** (because `trace: 'on-first-retry'`) | Break the canary assertion, then run with a retry so the trace is captured: `npx playwright test --retries=1` (or `CI=1 npm run e2e:smoke`). Inspect `test-results/`: screenshot + video appear immediately; `trace.zip` appears after the retry. |
| 4 | Deleting `canary.spec.ts` does not error the test run — `npm run e2e` exits `0` with "0 tests" (guaranteed by `--pass-with-no-tests` in the script; a raw `playwright test` would otherwise exit `1`) | Delete file, run `npm run e2e`, confirm exit code `0`, restore |
| 5 | `e2e/README.md` covers: pre-run (compose, hosts, `:8443`), env table, run commands, artifacts, tag convention, link to `qa_plan.md §5.2` | Manual review against §10 sections |
| 6 | `e2e/fixtures/base.ts` has TODO comments linking to `qa_plan.md §5.2` scenario numbers for `authenticatedPage` and `apiClient` | Code review |
| 7 | No new dependencies added to `ui/`, `api/`, or root `package.json` | `git diff` check |
| 8 | `e2e/test-results/`, `e2e/playwright-report/`, `e2e/reports/` are gitignored | `git status` after a run |

---

## 12. Implementation Order

Implement in this sequence to keep each step verifiable:

1. Create `e2e/package.json`, `e2e/tsconfig.json`.
2. Create `e2e/playwright.config.ts`.
3. Create `e2e/fixtures/base.ts` (stubs with TODOs).
4. Create `e2e/tests/canary.spec.ts`.
5. Create `e2e/utils/.gitkeep` and `e2e/.env.example`.
6. Add gitignore entries.
7. Run `npm run e2e:install` → verify no errors.
8. Start the local stack (`./start-services.sh`).
9. Run `npm run e2e:smoke` → verify green.
10. Break the canary assertion, re-run → verify `trace.zip` and screenshot appear in `test-results/`.
11. Restore canary, run 5 times → verify no flakes.
12. Write `e2e/README.md`.

---

## 13. Notes and Constraints

- **Port `:8443`** is the canonical HTTPS entry point for both UI (`notebook.com:8443`) and API (`api.notebook.com:8443`), as defined in `proxy/nginx.conf` and `docs/qa_plan.md §3`.
- **`ignoreHTTPSErrors: true`** is permanent for the local stack (self-signed cert from `proxy/`). In production/AWS the certificate will be valid; the flag causes no harm but may be removed in a separate environment-scoped config later.
- **`workers: 1` / `fullyParallel: false`** — conservative defaults. Increase only after auth fixtures share session state safely.
- **No `pnpm-workspace.yaml` changes required** — `e2e/` is an isolated package, run directly with `npm` or `pnpm` from the `e2e/` directory.
- **Test doubles for OTP / OAuth** — use fixed OTP (`E2E_TEST_OTP`) and a test OAuth application only in test/staging environments, never in production. See `docs/qa_plan.md §3`.
- **`HTTP-only` session cookie** — the browser context receives the cookie from the backend after successful auth (`system_architecture.md §3` decision 9). The `apiClient` fixture forwards cookies from the browser context, so authenticated API calls reuse the same session without a separate token.
- **No `webServer` block in `playwright.config.ts`** — the stack is provided externally by `docker-compose` + reverse proxy, so Playwright must **not** start or stop services. Pre-run (compose, `hosts`, `:8443`) is documented once in `e2e/README.md` instead. This keeps the package portable across local and AWS/CI without per-environment config.
- **`trace: 'on-first-retry'` vs. retries** — keeps green runs fast (no trace overhead) but a `trace.zip` is only written on a retry. CI sets `retries: 2`; locally pass `--retries=1` to force trace capture while debugging. Screenshot (`only-on-failure`) and video (`retain-on-failure`) are written on the first failure regardless.
- **`--pass-with-no-tests`** — included in the `e2e` and `e2e:smoke` scripts so removing the canary (DoD #4) or an empty `@smoke` filter still exits `0`.

---

## 14. Regeneration Prompt

> Use this prompt verbatim to fully regenerate the `e2e/` package from scratch and produce an identical result. The prompt is self-contained — it embeds all required decisions, constraints, and file contracts so no additional context is needed.

---

```
You are a senior software engineer, QA architect, and Python/Playwright/AWS specialist applying 2026 best practices.

Your task: implement the complete `e2e/` Playwright package for the JS Notebook monorepo according to the specification in `docs/prompts/QA-Implement-E2E-test-automation-with-Playwright-64.md`.

## Repository context

- Monorepo root: contains `api/` (FastAPI), `ui/` (React/Vite), `proxy/` (Nginx), `docker-compose.yaml`
- Local domains: `notebook.com` (UI), `api.notebook.com` (API) — both on port `:8443` HTTPS via Nginx reverse proxy
- Nginx upstream: `host.docker.internal:3000` (UI), `host.docker.internal:8000` (API)
- UI `@playwright/test` version: `^1.54.2` (from `ui/package.json`)
- Auth: Email + OTP and Google OAuth; HTTP-only session cookie (no bearer token in localStorage)
- Architecture docs: `docs/system_architecture.md`, `docs/tech_stack.md`, `docs/qa_plan.md`

## Package location and isolation

- Create `e2e/` at the monorepo root — NOT inside `ui/` or `api/`
- Do NOT modify `ui/`, `api/`, `proxy/`, or root `package.json`
- Do NOT add a `webServer` block to `playwright.config.ts` — the stack is external

## Files to create (exact content defined in the spec §3–§10)

1. `e2e/package.json` — spec §4; `@playwright/test ^1.54.2`, `@types/node ^22.0.0`, `typescript ^5.6.3`
2. `e2e/tsconfig.json` — spec §5; add `"types": ["node"]` to `compilerOptions`
3. `e2e/playwright.config.ts` — spec §6; env-driven, `ignoreHTTPSErrors: true`, `workers: 1`, `fullyParallel: false`, reporters: list + junit + html, chromium only
4. `e2e/fixtures/base.ts` — spec §7; stub fixtures `authenticatedPage` and `apiClient` with full TODO comments linking to `qa_plan.md §5.2`; suppress unused variable TS errors with `void`
5. `e2e/tests/canary.spec.ts` — spec §8; `{ tag: '@smoke' }` annotation, `page.goto('/')`, assert `status < 400` and `title.length > 0`
6. `e2e/utils/.gitkeep` — empty file
7. `e2e/.env.example` — spec §9; all 5 env vars with defaults, no secrets
8. `e2e/README.md` — spec §10; all 7 sections (Prerequisites, Stack, Running, Env vars, Artifacts, Tags, Future scenarios) plus AWS/CI notes and DoD table

## .gitignore entries to add (root `.gitignore`)

```
# E2E Playwright artifacts
e2e/node_modules/
e2e/test-results/
e2e/playwright-report/
e2e/reports/
e2e/.env
```

## After creating files, execute in order

1. `cd e2e && npm install` — installs `@playwright/test`, `@types/node`, `typescript`
2. `cd e2e && npx tsc --noEmit` — must produce zero errors
3. `cd e2e && npm run e2e:install` — installs Playwright Chromium browser and dependencies
4. Verify DoD #4: move `tests/canary.spec.ts` aside, run `npm run e2e`, confirm exit 0, restore the file
5. Verify gitignore: `git check-ignore -v e2e/test-results e2e/playwright-report e2e/reports e2e/.env e2e/node_modules`

## Acceptance criteria (Definition of Done — spec §11)

| # | Criterion |
|---|---|
| 1 | `npm run e2e:install` completes without errors |
| 2 | `npm run e2e:smoke` exits green against the running docker-compose stack 5× consecutively |
| 3 | On canary failure: screenshot + video appear in `test-results/` on first failure; `trace.zip` appears after `--retries=1` |
| 4 | `npm run e2e` exits 0 with "0 tests" when `canary.spec.ts` is deleted |
| 5 | `e2e/README.md` covers all §10 sections |
| 6 | `fixtures/base.ts` has TODO comments linking to `qa_plan.md §5.2` scenario numbers |
| 7 | No new dependencies in `ui/`, `api/`, or root `package.json` |
| 8 | `e2e/test-results/`, `e2e/playwright-report/`, `e2e/reports/` are gitignored |

## Key constraints

- `ignoreHTTPSErrors: true` is permanent (self-signed cert in local + CI stacks)
- `workers: 1`, `fullyParallel: false` — safe default until auth fixtures share session
- `--pass-with-no-tests` is mandatory in both `e2e` and `e2e:smoke` scripts
- `{ tag: '@smoke' }` is the Playwright tag annotation — NOT embedded in the test title string
- No `dotenv` package — env vars are passed inline or via shell `.env` sourcing
- `@types/node` must be listed in `devDependencies` and added to `tsconfig.json` `types` array
- Spec §12 defines the implementation order; follow it to keep each step independently verifiable
```

