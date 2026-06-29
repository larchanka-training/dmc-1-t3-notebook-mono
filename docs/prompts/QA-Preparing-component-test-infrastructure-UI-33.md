# SPEC: Preparing Component Test Infrastructure (UI)

> Spec-Driven Development (SDD) specification — June 2026 best practice.
> This document is **deterministic and self-contained**: it must allow an AI agent or a developer to
> regenerate the exact same result repeatedly, without guessing. Every artifact has a path, a
> responsibility, an explicit contract, and acceptance criteria.

---

## 1. Metadata

| Field | Value |
|-------|-------|
| Spec ID | `QA-UI-COMPONENT-TEST-INFRA` |
| Title | Preparing Component Test Infrastructure (UI) |
| Scope repository | `ui/` |
| Owner | QA + UI |
| Status | Approved for implementation |
| Canonical language | English (per `AGENTS.md`) |
| Source of truth | `docs/qa_plan.md` §5.1, `docs/tech_stack.md` (Frontend test stack) |
| Related | `docs/qa_plan.md` §5.2 (E2E Playwright), `e2e/` package |

### 1.1 Traceability to project documents

- `docs/tech_stack.md`: *Frontend test stack = `Vitest + React Testing Library` plus a small `Playwright` smoke layer*.
- `docs/qa_plan.md` §2: *UI integration → `ui` (`Vitest` + Testing Library)*; *E2E → `e2e/` package (`Playwright`)*.
- `docs/qa_plan.md` §5.1: component tests for block render, editor, sync indicators, **Auth UI with network mocks via MSW**.

---

## 2. Context & Problem

The `ui/` app (React 18 + TypeScript + Vite 5) currently has **no test infrastructure**: no test
runner, no DOM environment, no network mocking, no component-test conventions.

A frontend developer must be able to:

1. Drop a `*.test.tsx` file **next to the component** and start writing immediately.
2. Rely on a **pre-wired** DOM environment, assertion matchers, and **network mocking via MSW**.
3. Never create a manual setup file per test.

The infrastructure must also **coexist cleanly with the Playwright E2E layer** in `e2e/` (no port,
config, glob, or dependency collisions) and must **run identically on any environment** — macOS,
Windows, Linux, and AWS/CI — with no machine-specific assumptions.

---

## 3. Goals / Non-Goals

### 3.1 Goals

- Stand up **Vitest** + **React Testing Library** in `ui/`.
- Mock network with **MSW** (zero-config for test authors).
- Zero-config authoring: colocated `*.test.ts(x)`, shared setup auto-loaded.
- Coverage via **v8** provider into `ui/coverage/`.
- JUnit report into `ui/reports/junit-ui.xml`.
- **Playwright coexistence**: explicit boundaries so Vitest never picks up Playwright specs and vice versa.
- **Cross-environment determinism**: identical behavior on macOS, Windows, Linux, AWS/CI.

### 3.2 Non-Goals

- Writing real product tests beyond canaries.
- Implementing real providers (router/query-client/theme) — only a wired extension point.
- Building or modifying the Playwright E2E suite itself (only the non-collision contract).
- CI pipeline wiring (only producing CI-consumable artifacts: JUnit + coverage).

---

## 4. Constraints & Assumptions

| # | Constraint |
|---|------------|
| C1 | Stack is React 18, TypeScript 5.6, Vite 8, ESM (`"type": "module"`). Package manager is **pnpm** (not npm). |
| C2 | DOM environment is **`jsdom`** (primary). `happy-dom` is an allowed drop-in alternative. |
| C3 | Versions are **pinned to the Vite 8 / React 18 committed line**: Vitest 4.x, `@vitest/coverage-v8` 4.x, MSW 2.11.x, jsdom 29.x. (Earlier draft targeted Vitest 2.x / Vite 5; the committed tree is the source of truth — see §15.) |
| C4 | Tests must perform **no real network I/O**; MSW runs with `onUnhandledRequest: 'error'`. |
| C5 | Infrastructure is **independent of the canary examples** (deleting any canary must not break runs). |
| C6 | All paths are POSIX-relative; no absolute or OS-specific paths in config. |
| C7 | No reliance on a system browser; Vitest uses the in-process DOM, not a real browser. |

---

## 5. Target File Structure

```text
ui/
├── package.json                      # (edited) devDependencies + scripts
├── vite.config.ts                    # (edited) export shared alias map (extension point)
├── vitest.config.ts                  # (new) Vitest config, alias sync, coverage, reporters
├── tsconfig.vitest.json              # (new) TS types for test globals + jest-dom
├── README.md                         # (edited) "Tests" section
├── test/
│   ├── setup.ts                      # (new) jest-dom + MSW lifecycle + cleanup
│   ├── render.tsx                    # (new) RTL render wrapper with providers (stub + TODO)
│   └── msw/
│       ├── server.ts                 # (new) setupServer(...handlers)
│       └── handlers.ts               # (new) empty array + TODO
├── coverage/                         # (generated) v8 coverage artifacts
├── reports/
│   └── junit-ui.xml                  # (generated) JUnit report
└── src/
    └── __tests__/
        ├── canary.test.tsx           # (new) renders "ok", asserts text
        └── msw.test.ts               # (new) fetch to mocked URL, asserts MSW intercepts
```

---

## 6. Detailed Requirements (per artifact)

### 6.1 `ui/package.json`

**Responsibility:** declare test dependencies and scripts.

**`devDependencies` (add, pinned to the committed React 18 / Vite 8 line):**

| Package | Version range | Purpose |
|---------|---------------|---------|
| `vitest` | `^4.1.0` | Test runner |
| `@vitest/coverage-v8` | `^4.1.0` | v8 coverage provider |
| `@testing-library/react` | `^16.3.0` | Component rendering |
| `@testing-library/jest-dom` | `^6.9.0` | DOM matchers |
| `@testing-library/user-event` | `^14.6.0` | User interaction simulation |
| `msw` | `^2.11.0` | Network mocking |
| `jsdom` | `^29.1.0` | DOM environment (primary) |

> If `happy-dom` is chosen instead of `jsdom`, swap the dependency and set `environment: 'happy-dom'`.
> `@playwright/test` is already present in `ui/devDependencies` (shared E2E tooling/types); see §7 P2 reconciliation — it must **not** be imported from component test files but is allowed in `package.json`.

**`scripts` (add):**

```jsonc
{
  "test": "vitest run",
  "test:watch": "vitest",
  "test:coverage": "vitest run --coverage"
}
```

**Acceptance:** `pnpm install` resolves with no peer-dependency errors against React 18 / Vite 8.

---

### 6.2 `ui/vite.config.ts` (edit — alias single source of truth)

**Responsibility:** expose a **shared alias map** so Vitest and Vite never drift.

**Contract:**

- Export a named `alias` (or `resolve.alias`) object from a module importable by both configs.
- The committed app defines two aliases used across source and tests:
  - `@` → `./src`
  - `@test` → `./test`
  Test files import via these aliases (e.g. `@test/render`, `@test/msw/server`) rather than long relative paths.

```ts
import react from "@vitejs/plugin-react";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig, loadEnv } from "vite";

const projectRoot = path.dirname(fileURLToPath(import.meta.url));

// Single source of truth for path aliases (shared by Vite and Vitest).
export const alias: Record<string, string> = {
  "@": path.resolve(projectRoot, "./src"),
  "@test": path.resolve(projectRoot, "./test"),
};

export default defineConfig(({ mode }) => {
  loadEnv(mode, ".", "");
  return {
    plugins: [react()],
    resolve: { alias },
    // test block is intentionally absent — owned by vitest.config.ts
  };
});
```

**Acceptance:** `vitest.config.ts` imports `{ alias }` from `vite.config.ts`; no duplicated alias literals exist. The inline `test` block must **not** live in `vite.config.ts`.

---

### 6.3 `ui/vitest.config.ts` (new)

**Responsibility:** configure the runner deterministically.

**Mandatory options:**

| Option | Required value | Rationale |
|--------|----------------|-----------|
| `test.environment` | `'jsdom'` | DOM for component tests (C2) |
| `test.globals` | `true` | `describe/it/expect` without imports |
| `test.setupFiles` | `['./test/setup.ts']` | Auto-load matchers + MSW + cleanup |
| `test.css` | `true` | Component CSS imports must not crash |
| `test.include` | `['src/**/*.{test,spec}.{ts,tsx}']` | Colocated convention |
| `test.exclude` | `['node_modules', 'dist', 'e2e/**', '**/*.e2e.*', 'playwright/**']` | **Playwright coexistence** |
| `test.reporters` | `['default', ['junit', { outputFile: './reports/junit-ui.xml' }]]` | Human + CI |
| `test.coverage.provider` | `'v8'` | Required provider |
| `test.coverage.reportsDirectory` | `'./coverage'` | Artifacts in `ui/coverage/` |
| `test.coverage.reporter` | `['text', 'html', 'lcov']` | Local + CI-consumable |
| `resolve.alias` | imported `alias` from `vite.config.ts` | Single source of truth |

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import { alias } from "./vite.config";

export default defineConfig({
  plugins: [react()],
  resolve: { alias },
  test: {
    environment: "jsdom",
    globals: true,
    css: true,
    setupFiles: ["./test/setup.ts"],
    include: ["src/**/*.{test,spec}.{ts,tsx}"],
    exclude: ["node_modules", "dist", "e2e/**", "**/*.e2e.*", "playwright/**"],
    reporters: ["default", ["junit", { outputFile: "./reports/junit-ui.xml" }]],
    coverage: {
      provider: "v8",
      reportsDirectory: "./coverage",
      reporter: ["text", "html", "lcov"]
    }
  }
});
```

**Acceptance:** running `vitest run` writes `reports/junit-ui.xml`; `--coverage` writes `coverage/`.

---

### 6.4 `ui/tsconfig.vitest.json` (new)

**Responsibility:** give TypeScript the test globals and matcher types.

```jsonc
{
  "extends": "./tsconfig.app.json",
  "compilerOptions": {
    "types": ["vitest/globals", "@testing-library/jest-dom"]
  },
  "include": ["src", "test", "vitest.config.ts"]
}
```

**Acceptance:** editor/`tsc` recognizes `expect(...).toBeInTheDocument()` and global `describe/it`.

---

### 6.5 `ui/test/setup.ts` (new)

**Responsibility:** the only setup file; auto-loaded for every test.

**Must contain, in order:**

1. `import "@testing-library/jest-dom";`
2. Import the MSW `server`.
3. `beforeAll(() => server.listen({ onUnhandledRequest: "error" }))` — fail on unmocked requests (C4).
4. `afterEach(() => { server.resetHandlers(); cleanup(); })` — reset overrides + DOM cleanup (C5).
5. `afterAll(() => server.close())`.

```ts
import "@testing-library/jest-dom";
import { afterAll, afterEach, beforeAll } from "vitest";
import { cleanup } from "@testing-library/react";
import { server } from "./msw/server";

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => {
  server.resetHandlers();
  cleanup();
});
afterAll(() => server.close());
```

**Acceptance:** no test imports this file manually; matchers and MSW work everywhere.

---

### 6.6 `ui/test/msw/handlers.ts` (new)

```ts
import type { RequestHandler } from "msw";

// TODO: add handlers as backend endpoints appear (auth OTP, notebooks CRUD, sync, AI broker).
export const handlers: RequestHandler[] = [];
```

### 6.7 `ui/test/msw/server.ts` (new)

```ts
import { setupServer } from "msw/node";
import { handlers } from "./handlers";

export const server = setupServer(...handlers);
```

**Acceptance:** importing `server` starts/stops cleanly; empty handler list is valid.

---

### 6.8 `ui/test/render.tsx` (new)

**Responsibility:** single render entry point with a provider tree extension point.

```tsx
import type { ReactElement, ReactNode } from "react";
import { render, type RenderOptions } from "@testing-library/react";

// TODO: wrap with real providers as they are introduced
//   (Router, Query Client, Zustand store boundary, Theme provider).
function AllProviders({ children }: { children: ReactNode }) {
  return <>{children}</>;
}

export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, "wrapper">
) {
  return render(ui, { wrapper: AllProviders, ...options });
}

export * from "@testing-library/react";
export { renderWithProviders as render };
```

**Acceptance:** tests can `import { render } from "../../test/render"` and get the wrapped renderer.

---

### 6.9 Canary `ui/src/__tests__/canary.test.tsx` (new)

```tsx
import { describe, expect, it } from "vitest";
import { render, screen } from "../../test/render";

describe("canary: rendering", () => {
  it("renders ok", () => {
    render(<div>ok</div>);
    expect(screen.getByText("ok")).toBeInTheDocument();
  });
});
```

### 6.10 Canary `ui/src/__tests__/msw.test.ts` (new)

```ts
import { afterEach, describe, expect, it } from "vitest";
import { http, HttpResponse } from "msw";
import { server } from "../../test/msw/server";

describe("canary: MSW intercepts fetch", () => {
  it("returns mocked payload", async () => {
    server.use(
      http.get("https://example.test/api/ping", () =>
        HttpResponse.json({ ok: true })
      )
    );

    const res = await fetch("https://example.test/api/ping");
    const body = await res.json();

    expect(res.ok).toBe(true);
    expect(body).toEqual({ ok: true });
  });
});
```

**Acceptance (both canaries):** deleting either file keeps the suite runnable (infra is independent, C5).

---

## 7. Playwright Coexistence Requirements (NEW)

The component-test layer (Vitest) and the E2E layer (Playwright, `e2e/`) must run **side by side**
without interference. The implementation must guarantee:

| # | Requirement |
|---|-------------|
| P1 | **Glob isolation:** Vitest `include` matches only `src/**/*.{test,spec}.{ts,tsx}`; Vitest `exclude` lists `e2e/**`, `playwright/**`, `**/*.e2e.*`. Playwright `testMatch` targets only `*.e2e.*` / its own `e2e/` directory. No file is collected by both runners. |
| P2 | **Dependency isolation:** Playwright browsers and the E2E suite stay in the `e2e/` package. `@playwright/test` **is present** in `ui/devDependencies` (shared tooling/types) but must **never** be imported from a Vitest component test or collected by Vitest. Vitest must **not** be a dependency of `e2e/`. |
| P3 | **No port/server collision:** Vitest runs fully in-process (no dev server, no port). Playwright owns `E2E_BASE_URL` / the proxy `:8443`. Neither layer starts the other’s services. |
| P4 | **Report isolation:** Vitest JUnit → `ui/reports/junit-ui.xml`; Playwright reports → `e2e/reports/` (and `e2e/playwright-report/`). Output paths never overlap. |
| P5 | **Independent commands:** `npm run test` (in `ui/`) runs only Vitest; the Playwright suite is invoked from `e2e/` only. Running one must never trigger the other. |
| P6 | **Shared MSW handlers, separate transport (optional):** MSW `node` server is for Vitest only. Playwright must not import `msw/node`; if browser-level mocking is ever needed it uses `msw/browser` in `e2e/` independently. The `handlers.ts` array may be shared by import, but transport setup stays per-layer. |
| P7 | **Coexistence verification step:** the implementer must run **both** `ui` Vitest and the `e2e` Playwright suites in sequence and confirm zero cross-collection, zero port conflicts, and distinct report artifacts. |

---

## 8. Cross-Environment Configuration Requirements (NEW)

The infrastructure must produce **identical results** on macOS, Windows, Linux, and AWS/CI runners.

| # | Requirement |
|---|-------------|
| E1 | **No OS-specific paths:** all config paths are POSIX-relative (`./reports/...`, `./coverage`). No drive letters, no `\\` separators, no absolute paths. |
| E2 | **No real browser dependency:** Vitest uses `jsdom` in-process; nothing requires a system Chrome/WebKit. This is what keeps it runnable on headless AWS/CI. |
| E3 | **Deterministic network:** `onUnhandledRequest: 'error'` guarantees a test fails the same way on every machine instead of leaking to the real network. |
| E4 | **Pinned versions (C3):** ranges are constrained so `npm ci` resolves the same tree on every OS; a committed lockfile is required for byte-identical installs. |
| E5 | **Cross-platform scripts:** npm scripts use only `vitest` invocations (no `rm`, `cp`, `&&` shell-specifics, no `NODE_ENV=...` inline assignment). Any env var needed in CI is provided by the runner, not the script. |
| E6 | **CI artifacts are standard:** JUnit XML (`ui/reports/junit-ui.xml`) and `lcov` (`ui/coverage/lcov.info`) are consumable by GitHub Actions / AWS CodeBuild without transformation. |
| E7 | **Locale/timezone safety:** tests must not depend on system locale or timezone; if a test needs them, it sets them explicitly (documented convention). |
| E8 | **Node engine pin:** document a supported Node LTS range (e.g. Node ≥ 20) in `ui/README.md` so all environments install a compatible toolchain. |
| E9 | **Single-threaded fallback note:** document that constrained CI/AWS runners may set `--pool=forks` or `--no-file-parallelism` if sandbox limits worker threads; default config must still pass without it. |

---

## 9. `ui/README.md` — "Tests" section (edit)

Must document:

1. **Commands:** `npm run test`, `npm run test:watch`, `npm run test:coverage`.
2. **Convention:** colocate `*.test.ts(x)` / `*.spec.ts(x)` next to the source; no per-test setup files.
3. **Rendering:** import `render` from `test/render.tsx`; add real providers there once introduced.
4. **Adding an MSW handler:** append to `test/msw/handlers.ts`; override per-test with `server.use(...)`.
5. **Artifacts:** coverage in `ui/coverage/`, JUnit in `ui/reports/junit-ui.xml`.
6. **Playwright boundary:** Vitest is component-level; E2E lives in `e2e/` (Playwright) and is run separately.
7. **Environment support:** runs on macOS/Windows/Linux/AWS-CI; Node LTS ≥ 20; no real browser required.

---

## 10. Acceptance Criteria / Definition of Done

| # | Criterion |
|---|-----------|
| DoD1 | `npm run test` is **green locally** and runs **both** canaries. |
| DoD2 | `npm run test:coverage` produces a report in `ui/coverage/`. |
| DoD3 | MSW intercepts `fetch` in the canary with **no failures and no warnings**. |
| DoD4 | `ui/README.md` updated: commands, convention, artifacts. |
| DoD5 | Deleting **any** canary does not break the run (infra independent of examples). |
| DoD6 | `ui/reports/junit-ui.xml` is generated by `npm run test`. |
| DoD7 | **Playwright coexistence (§7) verified:** running Vitest and the `e2e/` Playwright suite back-to-back shows zero cross-collection, zero port conflicts, distinct artifacts. |
| DoD8 | **Cross-environment (§8) verified:** identical pass result on at least one POSIX (macOS/Linux) and one Windows/CI context (or documented CI run), using `npm ci` + lockfile. |
| DoD9 | No new test dependency leaks into `e2e/`, and `@playwright/test` is **not imported** from any Vitest component test (its presence in `ui/devDependencies` is allowed). |

---

## 11. Verification Plan (commands)

```bash
# from ui/
npm install            # or: npm ci  (deterministic, uses lockfile)
npm run test           # both canaries green, junit-ui.xml written
npm run test:coverage  # coverage/ generated

# coexistence (run separately; must not interfere)
# from e2e/
npx playwright test    # E2E suite; reports into e2e/reports, no Vitest collected
```

Expected artifacts after a run:

- `ui/reports/junit-ui.xml`
- `ui/coverage/` (including `lcov.info` and HTML report)

---

## 12. Idempotency & Reproducibility Notes

- **Pinned versions + committed lockfile** → identical dependency tree across machines.
- **No real network** (`onUnhandledRequest: 'error'`) → deterministic outcomes.
- **In-process DOM** (`jsdom`) → no system-browser variance.
- **POSIX-relative paths + cross-platform scripts** → identical behavior on Mac/Win/Linux/AWS.
- **Single alias source** (`vite.config.ts`) → config never drifts between runners.
- Regenerating from this spec must always yield the same files and the same green result.

---

## 13. Out-of-Scope / Future

- Real providers in `test/render.tsx` (Router, Query Client, Zustand, Theme).
- Real MSW handlers for auth/notebooks/sync/AI endpoints.
- Wiring `junit-ui.xml` + `lcov` into the CI pipeline (GitHub Actions / AWS CodeBuild).
- Optional switch from `jsdom` to `happy-dom` for speed.

---

## 14. Traceability Matrix

| Requirement (source) | Artifact | Acceptance |
|----------------------|----------|------------|
| Vitest + RTL stand-up | `package.json`, `vitest.config.ts` | DoD1 |
| MSW network mock, zero-config | `test/setup.ts`, `test/msw/*` | DoD3 |
| Colocated `*.test.tsx`, no per-test setup | `vitest.config.ts` `include`, `test/setup.ts` | DoD1, README |
| Coverage v8 → `ui/coverage/` | `vitest.config.ts` `coverage` | DoD2 |
| JUnit → `ui/reports/junit-ui.xml` | `vitest.config.ts` `reporters` | DoD6 |
| Render helper with providers | `test/render.tsx` | §9.3 |
| Canaries (render + MSW) | `src/__tests__/*` | DoD1, DoD5 |
| Infra independent of canaries | structure §5, setup §6.5 | DoD5 |
| Docs | `ui/README.md` Tests section | DoD4 |
| Playwright coexistence | §7 P1–P7, `vitest.config.ts` `exclude` | DoD7, DoD9 |
| Any-environment run (Mac/Win/AWS) | §8 E1–E9, lockfile, scripts | DoD8 |

---

## 15. Current Committed State (Authoritative for Regeneration)

> This section reflects the **actual committed `ui/` tree** as of 2026-06. Where it differs
> from the illustrative examples in §6, **this section wins** for regeneration fidelity. The
> infrastructure has been wired into real app providers and an auth feature; the original
> "empty stub" examples are the starting point, this is the landed result.

### 15.1 File structure (as committed)

```text
ui/
├── vite.config.ts                      # exports alias { "@", "@test" } + env/proxy server config
├── vitest.config.ts                    # owns all test config; coverage.reportOnFailure: true
├── tsconfig.vitest.json                # unchanged from §6.4
├── test/
│   ├── setup.ts                        # extended: jest-dom/vitest, MSW, store/query/auth reset, jsdom patches
│   ├── render.tsx                      # re-exports renderWithProviders as `render` + RTL
│   ├── renderWithProviders.tsx         # real QueryClientProvider wrapper, returns { queryClient, ...rtl }
│   ├── authFixtures.ts                 # shared auth test fixtures
│   └── msw/
│       ├── server.ts                   # setupServer(...authHandlers)
│       ├── handlers.ts                 # aggregation point: [...authHandlers] + TODO for more
│       └── handlers/
│           └── auth.ts                 # real auth handlers + resetAuthMockState / setMockSessionAuthenticated
└── src/__tests__/
    ├── canary.test.tsx                 # imports from "@test/render"
    └── msw.test.ts                     # imports from "@test/msw/server"
```

### 15.2 `vitest.config.ts` deltas vs §6.3

- `coverage.reportOnFailure: true` (Vitest 4 default is `false`) so CI gets lcov/html even on a failing suite.
- `exclude` uses `"**/*.e2e.{ts,tsx}"` (typed) instead of the looser `"**/*.e2e.*"`.
- Otherwise identical: `jsdom`, `globals`, `css: true`, `setupFiles: ["./test/setup.ts"]`,
  `include: ["src/**/*.{test,spec}.{ts,tsx}"]`, JUnit → `./reports/junit-ui.xml`, v8 → `./coverage`.

### 15.3 `test/setup.ts` deltas vs §6.5

The setup file is **not** the minimal stub; it must (in addition to MSW lifecycle):

1. `import "@testing-library/jest-dom/vitest";` (the `/vitest` entry, not the bare package).
2. `beforeAll(() => server.listen({ onUnhandledRequest: "error" }))` and `afterAll(() => server.close())`.
3. `afterEach` resets, in order: `server.resetHandlers()`, `resetAuthMockState()`,
   `queryClient.clear()`, `cleanup()`.
4. Reset the Zustand singleton between tests using `useAppStore.getInitialState()`.
5. **jsdom compatibility patches (test-env only):**
   - Conditionally strip an incompatible `AbortSignal` from the global `Request` so
     react-router data-router navigations construct under jsdom/undici.
   - Stub `Range.prototype.getClientRects` so CodeMirror layout measurement does not throw.

### 15.4 MSW (deltas vs §6.6 / §6.7)

- `handlers.ts` is **not empty** — it aggregates `authHandlers` and keeps the TODO list for
  notebooks/sync/AI handler modules under `test/msw/handlers/`.
- `server.ts` spreads the auth handlers: `setupServer(...authHandlers)`.
- `test/msw/handlers/auth.ts` provides real handlers for `POST /api/v1/auth/request-otp`,
  `POST /api/v1/auth/verify-otp`, `GET /api/v1/auth/session`, plus mutable-state helpers
  `resetAuthMockState()` (called from `setup.ts` `afterEach`) and `setMockSessionAuthenticated()`.

### 15.5 Render helpers (deltas vs §6.8)

The render entry point is **split into two files**:

- `test/renderWithProviders.tsx` — wraps the tree in a fresh per-render `QueryClientProvider`
  (`retry: false`), returns `{ queryClient, ...renderResult }`. New providers (Router, Theme,
  Zustand boundary) are added here.
- `test/render.tsx` — re-exports `renderWithProviders as render` and `* from "@testing-library/react"`.
  This is the stable public API; tests import `{ render, screen } from "@test/render"`.

### 15.6 Canaries (deltas vs §6.9 / §6.10)

- Import via aliases (`@test/render`, `@test/msw/server`), not relative paths.
- `canary.test.tsx` additionally asserts a providers-wrapper render (role `region`).
- `msw.test.ts` additionally asserts per-test handler reset (isolation) across two `it` blocks.

### 15.7 Tooling / environment (deltas)

- Package manager is **pnpm**; documented commands are `pnpm test`, `pnpm test:watch`,
  `pnpm test:coverage` (npm equivalents still valid).
- Stack line is **Vite 8 / Vitest 4 / jsdom 29 / msw 2.11**, not the Vite 5 / Vitest 2 draft.
- `@playwright/test` remains in `ui/devDependencies` (shared E2E tooling) and is excluded from
  Vitest collection — it must never be imported from a component test (see §7 P2, DoD9).
