# JS Notebook — Frontend

Frontend application for the JavaScript-notebook product. React + TypeScript SPA.

Stack: **React 18**, **TypeScript**, **Vite**, **Tailwind CSS v3**, **shadcn/ui**, **React Router v6**, **Zustand**, **Vitest + React Testing Library**.

Package manager: **`pnpm`** only (see [`docs/index.md`](./docs/index.md#repository-tooling)).

## Quick start

```bash
pnpm install
pnpm dev
```

Open the local URL from Vite (usually `http://localhost:5173`), or `https://notebook.com` when running the full monorepo via Docker (see monorepo `docs/Local-Proxy.md`).

## Local AI rollout

`WebLLM` local mode is disabled by default. The intended rollout policy for the current slice is `dev-opt-in`, so the normal backend-first AI flow remains the baseline in every environment unless the frontend runtime is explicitly configured otherwise.

To enable local mode in local development:

```env
VITE_WEBLLM_LOCAL_MODE_ROLLOUT_POLICY=dev-opt-in
VITE_WEBLLM_LOCAL_MODE_ENABLED=true
```

For QA or product validation, treat `public-opt-in` as an explicit override rather than a default production posture. The notebook AI UI may still render a visible `Local WebLLM` panel and `Generate locally` button while local mode is unavailable, but those controls must remain disabled and explained until runtime preparation and policy checks pass.

## Documentation

Canonical UI specs live in [`docs/`](./docs/). Start with [`docs/index.md`](./docs/index.md) for navigation.

| Document                                               | Role                                                                                                                                                                         |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`docs/ui_architecture.md`](./docs/ui_architecture.md) | **Canonical** Version 1 UI architecture: routes, screens, FSD layout, public API rules, Zustand model, provider composition, internal data flows, fixed technology decisions |
| [`docs/state_model.md`](./docs/state_model.md)         | Persistent, ephemeral, and derived state mapping                                                                                                                             |
| [`docs/zusthand-store.md`](./docs/zusthand-store.md)   | Store-by-store Zustand responsibilities                                                                                                                                      |
| [`docs/libs.md`](./docs/libs.md)                       | Approved libraries and versions                                                                                                                                              |
| [`docs/plan.md`](./docs/plan.md)                       | Recommended implementation sequence                                                                                                                                          |
| [`docs/screen_specs.md`](./docs/screen_specs.md)       | Screen-level Version 1 specs                                                                                                                                                 |
| [`docs/adr/`](./docs/adr/)                             | Architecture decision records                                                                                                                                                |

**Read order for most tasks:** `ui_architecture.md` → `libs.md` → `zusthand-store.md` → `state_model.md` → relevant ADRs and topic docs (`api_contracts.md`, `runtime_architecture.md`, etc.). See [`docs/index.md`](./docs/index.md).

Russian companions (`*RU.md`) are for human reading only; implementation must follow the English documents.

Agent bootstrap: [`AGENTS.md`](./AGENTS.md).

## Mock authentication

The app opens at `/login`; `/notebooks` and `/notebooks/:notebookId` are
gated and redirect to `/login` until you sign in.

To sign in (deterministic mock — **not real security**, see Scope):

1. Enter any valid-format email → **Send code** → moves to the verify step.
2. Enter the one-time code **`1234`** (`MOCK_OTP` in `features/auth/model/constants.ts`) → redirects to `/notebooks`.
3. A wrong code shows an inline error and stays on the verify step.

The "Continue with Google" button is a no-op stub. The signed-in state
(`isAuthenticated` + `userEmail`) is persisted to `localStorage` under the
key `js-notebook-auth`, so a page reload keeps you signed in; clear that key
(or browser storage) to sign out. The header shows the brand only until you
authenticate, then the `Notebooks` nav link appears.

> The `RequireAuth` guard is **client-side UX only**. Real authentication is
> a later task and must be enforced server-side — do not treat this as a
> security boundary.

## Scripts

- `pnpm dev` — development server
- `pnpm build` — typecheck (`tsc -b`) + production build
- `pnpm preview` — preview the production build
- `pnpm lint` — ESLint (FSD layer boundaries) + Steiger (`--max-warnings 0`)
- `pnpm lint:fsd` — Steiger only (`./src`)
- `pnpm typecheck` — `tsc -b --noEmit`
- `pnpm test` — run the test suite once (Vitest)
- `pnpm test:watch` — Vitest in watch mode
- `pnpm verify` — typecheck, lint (ESLint + Steiger), format check, tests (same as pre-commit hook)

Git hooks ([Husky](https://typicode.github.io/husky/)): after `pnpm install`, `pre-commit` runs `pnpm verify:commit` (lint-staged → typecheck → ESLint + Steiger → tests). Full repo check including Prettier on all files: `pnpm verify`. Skip hook once with `git commit --no-verify` if needed.

Add shadcn components: `pnpm dlx shadcn@latest add <component>` (see [`docs/libs.md`](./docs/libs.md)).

---

## Tests

> Spec: `docs/prompts/QA-Preparing-component-test-infrastructure-UI.md` — `QA-UI-COMPONENT-TEST-INFRA`

### Commands

| Command              | What it does                                   |
| -------------------- | ---------------------------------------------- |
| `pnpm test`          | Run all tests once (Vitest, non-watch)         |
| `pnpm test:watch`    | Vitest in interactive watch mode (development) |
| `pnpm test:coverage` | Run tests + generate v8 coverage report        |

### File convention

Colocate test files **next to the source they test**:

```text
src/features/auth/ui/LoginForm.tsx
src/features/auth/ui/LoginForm.test.tsx   ← colocated
```

Accepted patterns: `*.test.ts`, `*.test.tsx`, `*.spec.ts`, `*.spec.tsx`.
No per-test setup file is needed — `test/setup.ts` is auto-loaded by Vitest.

### Rendering components

Import `render` from the central wrapper so all tests use the same provider tree:

```tsx
import { render, screen } from "@test/render";

it("renders the notebook title", () => {
  render(<NotebookTitle title="My notebook" />);
  expect(screen.getByText("My notebook")).toBeInTheDocument();
});
```

The wrapper lives in `test/render.tsx` → `test/renderWithProviders.tsx`.  
Add real providers (Router, Query Client, Zustand boundary, Theme) to `renderWithProviders.tsx` as they are introduced.

### Adding an MSW network handler

1. Open `test/msw/handlers.ts` (the aggregation point).
2. Add a new handler file under `test/msw/handlers/` (e.g. `notebooks.ts`).
3. Import and spread it into the `handlers` array in `handlers.ts`.
4. For a one-off per-test override, use `server.use(...)` inside the test — it is reset automatically by `afterEach`.

```ts
// test/msw/handlers/notebooks.ts
import { http, HttpResponse } from "msw";
import { TEST_API_BASE } from "./auth"; // absolute base URL from VITE_API_BASE_URL
export const notebookHandlers = [
  http.get(`${TEST_API_BASE}/notebooks`, () => HttpResponse.json({ notebooks: [] })),
];

// test/msw/handlers.ts  — import and spread:
import { notebookHandlers } from "./handlers/notebooks";
export const handlers = [...authHandlers, ...notebookHandlers];
```

> **Important:** always use `TEST_API_BASE` (exported from `test/msw/handlers/auth.ts`) for
> handler URLs. MSW node transport matches **exact URLs** — a relative path like
> `"/api/v1/notebooks"` will never match `http://localhost:8000/api/v1/notebooks`.

### Artifacts

| Artifact           | Location                  |
| ------------------ | ------------------------- |
| Coverage HTML      | `ui/coverage/index.html`  |
| Coverage LCOV (CI) | `ui/coverage/lcov.info`   |
| JUnit XML (CI)     | `ui/reports/junit-ui.xml` |

Both directories are created automatically by Vitest on first run.

### Playwright boundary (E2E)

Component tests run in-process via **jsdom** — no browser needed.  
End-to-end tests (Playwright) live in the **`e2e/` package** and run separately:

```bash
# From the monorepo root e2e/ package — not from ui/
npx playwright test
```

Vitest never collects `*.e2e.*` files or anything under `e2e/`.  
`@playwright/test` must not be imported in component test files.

### Environment requirements

- **Node LTS ≥ 20** — required on macOS, Windows, Linux, and AWS/CI.
- No real browser needed — jsdom provides the DOM environment in-process.
- All config paths are POSIX-relative — identical behavior on all OS.
- For constrained CI runners: `pnpm test -- --pool=forks` disables worker threads if sandbox limits apply.

---

## Project structure

`src/` follows **Feature-Sliced Design (FSD)** per [`docs/ui_architecture.md`](./docs/ui_architecture.md) §4.

**Import direction (mandatory):**

```text
app → pages → features → entities → shared
```

Layers may import only from the same layer (via public API) or from layers below. No upward or cross-feature imports unless composed at `pages/`.

### Directory layout

```text
test/                 # Vitest setup and shared test utilities (outside FSD src/)
src/
  app/
    providers/
    router/
    styles/
    index.tsx
  pages/
    login/
    notebooks-list/
    notebook-editor/
  features/
    auth/
    notebooks/
    editor/
    execution/
    sync/
    ai/
  entities/
    notebook/
    block/
    output/
    session/
    user/
  shared/
    api/
    config/
    lib/
    persistence/
    ui/
    types/
```

### Slice segments

Slices under `features/`, `entities/`, and `shared/` use FSD segments where needed:

| Segment    | Typical contents                                   |
| ---------- | -------------------------------------------------- |
| `ui/`      | Components and presentational views                |
| `model/`   | Zustand slice segments, selectors, actions         |
| `api/`     | Request adapters and DTO mappers                   |
| `lib/`     | Pure helpers internal to the slice                 |
| `index.ts` | **Public API** — only entry point for other layers |

`pages/` slices are route composition only (`ui/` + `index.ts`). Import features and entities through their public APIs, not deep paths like `features/auth/ui/LoginForm`.

### Routes → slices

| Route                    | Page slice               | Main feature slices                                                     |
| ------------------------ | ------------------------ | ----------------------------------------------------------------------- |
| `/login`                 | `pages/login/`           | `features/auth`                                                         |
| `/notebooks`             | `pages/notebooks-list/`  | `features/notebooks`, `features/auth`                                   |
| `/notebooks/:notebookId` | `pages/notebook-editor/` | `features/editor`, `features/execution`, `features/sync`, `features/ai` |

### Zustand ownership

| Store segment                         | Primary owner               |
| ------------------------------------- | --------------------------- |
| `authStore`                           | `features/auth/model/`      |
| `notebookListStore`                   | `features/notebooks/model/` |
| `activeNotebookStore`, `blockUiStore` | `features/editor/model/`    |
| `executionStore`                      | `features/execution/model/` |
| `syncStore`                           | `features/sync/model/`      |
| `appUiStore`                          | `app/` or `shared/`         |

Slice stores may be composed in `app/model/` during migration; logic stays owned by the feature above. No store segment should own both durable notebook content and execution outputs.

Full rules (layer responsibilities, provider tree, data flows): [`docs/ui_architecture.md`](./docs/ui_architecture.md) §4, §16–17.

Automated FSD checks: [`docs/adr/ADR-014-fsd-architecture-lint.md`](./docs/adr/ADR-014-fsd-architecture-lint.md) (`pnpm lint`, `pnpm lint:fsd`).

## Scope

This is the **foundation/scaffold**. The login flow is wired as a deterministic
**mock** (see [Mock authentication](#mock-authentication)). Real (server-side)
authentication, code execution, IndexedDB persistence, the CodeMirror code
editor, Markdown editing, sync, and AI are delivered by later tasks — not
present here by design. Remaining forms and action buttons (e.g. Google
sign-in) are wired to named no-op stub handlers until then.

Tests run under jsdom; `test/setup.ts` includes a conditional Request-signal
shim so react-router data-router redirects work under Node + undici.
