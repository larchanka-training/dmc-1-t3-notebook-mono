# e2e — Playwright End-to-End Tests

Standalone Playwright package for the JS Notebook monorepo. Runs identically against the local `docker-compose` stack and AWS/CI environments via environment variables.

Reference specification: `docs/prompts/QA-Implement-E2E-test-automation-with-Playwright-64.md`

---

## 10.1 Prerequisites (one-time setup per machine)

1. **Docker / Docker Compose** — install if not present: https://docs.docker.com/get-docker/

2. **`hosts` entries** — add to `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):
   ```
   127.0.0.1 notebook.com
   127.0.0.1 api.notebook.com
   ```

3. **Browser certificate trust** (optional — removes browser warnings):
   See `docs/Local-Proxy.md` for `mkcert` instructions.
   E2E tests bypass certificate warnings via `ignoreHTTPSErrors: true` and do not require manual trust.

4. **Playwright browsers** — run once after cloning:
   ```bash
   cd e2e
   # macOS / Windows — installs browser binary only (system deps already present):
   npx playwright install chromium
   # Linux (CI, Docker, WSL) — also installs OS-level system dependencies:
   npm run e2e:install
   ```

---

## 10.2 Starting the stack

```bash
# From the monorepo root
./start-services.sh
# Or manually:
docker compose up -d
```

The reverse proxy listens on:
- `:8080` — HTTP (`notebook.com`, `api.notebook.com`)
- `:8443` — HTTPS (`notebook.com`, `api.notebook.com`)

E2E tests use `:8443` (HTTPS) as the canonical base URL.

---

## 10.3 Running tests

> **Note — package manager:** `e2e/` uses **npm** (not pnpm). The monorepo root and `ui/` use pnpm, but `e2e/` is an isolated standalone package. Always run `npm install` / `npm run …` inside `e2e/`, never `pnpm install`.

```bash
cd e2e

# Install dependencies (first time after clone)
npm install

# Full suite
npm run e2e

# Smoke suite only (canary + future @smoke-tagged tests)
npm run e2e:smoke

# With a custom base URL
E2E_BASE_URL=https://notebook.com:8443 npm run e2e:smoke

# Open the HTML report from the last run
npm run e2e:report
```

---

## 10.4 Environment variables

All variables have safe local defaults. No `.env` file is required for a first `e2e:smoke` run against the local stack.

| Variable | Default | Purpose |
|---|---|---|
| `E2E_BASE_URL` | `https://notebook.com:8443` | UI entry point (reverse proxy HTTPS) |
| `E2E_API_BASE_URL` | `https://api.notebook.com:8443` | API base URL (reverse proxy HTTPS) |
| `E2E_TEST_USER_EMAIL` | *(empty)* | Email address used in OTP login flow for authenticated tests |
| `E2E_TEST_OTP` | *(empty)* | Fixed OTP for test/staging environments (never used in production; see `docs/qa_plan.md §3`) |
| `E2E_GOOGLE_AUTH_ENABLED` | `false` | Set to `true` to enable Google OAuth test paths; requires a test OAuth application or callback stub |

Store values for non-default environments in a local `.env` file at `e2e/.env` (gitignored):

```bash
cp e2e/.env.example e2e/.env
# then edit e2e/.env with your values
```

For CI, pass all vars as environment secrets; no `.env` file is required if all vars have acceptable defaults.

---

## 10.5 Artifacts

After a run (especially on failure):

| Artifact | Location | How to view |
|---|---|---|
| Trace (`.zip`) | `e2e/test-results/<test-name>/trace.zip` | `npx playwright show-trace e2e/test-results/.../trace.zip` |
| Screenshot (`.png`) | `e2e/test-results/<test-name>/` | Open directly |
| Video (`.webm`) | `e2e/test-results/<test-name>/` | Open directly |
| JUnit XML | `e2e/reports/junit-e2e.xml` | Import into CI / test reporter |
| HTML report | `e2e/playwright-report/` | `npx playwright show-report e2e/playwright-report` |

**Artifact capture behaviour:**
- Screenshot and video are written on the **first** failure (`only-on-failure`, `retain-on-failure`).
- `trace.zip` is written on **retry** (`trace: 'on-first-retry'`). To force trace capture locally: `npx playwright test --retries=1` or `CI=1 npm run e2e:smoke`.

---

## 10.6 Tag convention

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

A test may carry multiple tags:

```ts
test('login via OTP', { tag: ['@smoke', '@auth'] }, async ({ authenticatedPage }) => { ... });
```

---

## 10.7 Future scenarios

For required E2E scenarios and their acceptance criteria, see `docs/qa_plan.md §5.2`.

Each future test file should:
1. Be placed in `e2e/tests/`.
2. Import `{ test, expect }` from `../fixtures/base`.
3. Apply the matching tag from §10.6.
4. Use the `authenticatedPage` fixture for scenarios requiring auth.
5. Use the `apiClient` fixture for direct API verification (sync, conflict, export).

---

## AWS / CI deployment notes

When deploying to AWS or CI:

- Pass `E2E_BASE_URL` and `E2E_API_BASE_URL` as environment secrets pointing to your deployed environment.
- Set `CI=true` to enable `forbidOnly` and `retries: 2`.
- Run `npm run e2e:install` before the test step (or cache the Playwright browser binaries in CI).
- Collect `e2e/reports/junit-e2e.xml` as a test artifact for the CI test reporter.
- Collect `e2e/test-results/` and `e2e/playwright-report/` as build artifacts for failure diagnosis.

Example GitHub Actions step:

```yaml
- name: Install Playwright browsers
  working-directory: e2e
  run: npm run e2e:install

- name: Run E2E smoke suite
  working-directory: e2e
  env:
    CI: "true"
    E2E_BASE_URL: ${{ secrets.E2E_BASE_URL }}
    E2E_API_BASE_URL: ${{ secrets.E2E_API_BASE_URL }}
  run: npm run e2e:smoke

- name: Upload E2E artifacts
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: playwright-artifacts
    path: |
      e2e/test-results/
      e2e/playwright-report/
      e2e/reports/junit-e2e.xml
```

---

## Definition of Done verification

| # | Criterion | Command |
|---|---|---|
| 1 | `npm run e2e:install` completes without errors | `cd e2e && npm run e2e:install` |
| 2 | `npm run e2e:smoke` green 5× consecutively | `cd e2e && for i in {1..5}; do npm run e2e:smoke \|\| break; done` |
| 3 | Failure artifacts appear (screenshot+video on fail; trace on retry) | Break assertion, run `CI=1 npm run e2e:smoke` |
| 4 | `--pass-with-no-tests` keeps exit `0` when no tests match | Delete `canary.spec.ts`, run `npm run e2e`, check exit `0` |
| 5 | README covers all required sections | Manual review against spec §10 |
| 6 | `fixtures/base.ts` has TODO comments linking to `qa_plan.md §5.2` | Code review |
| 7 | No new deps in `ui/`, `api/`, root `package.json` | `git diff` |
| 8 | Artifact dirs are gitignored | `git status` after a run |
