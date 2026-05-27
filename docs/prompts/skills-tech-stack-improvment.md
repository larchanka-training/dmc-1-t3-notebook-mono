# Task: Update AI Agent Skill Files for Project-Specific Stack

## Objective

Update three skill files in `.agents/skills/` to replace generic "discover the stack" patterns with project-specific inline guidance. Only make changes that materially improve code generation quality and reduce hallucination for AI agents working in this monorepo.

## Context

- Repository: JavaScript notebook platform monorepo (api/ + ui/ + proxy/)
- Backend: Python 3.12+, FastAPI, SQLAlchemy 2.0 ORM, Alembic, Pydantic v2, PostgreSQL 16, pytest + TestClient
- Frontend: React 18, TypeScript 5.6, Vite 8, Zustand 5 (slice pattern), TanStack React Query 5, React Router v7, shadcn/ui + Radix + Tailwind, Zod 4, CodeMirror 6, Dexie 4, MSW 2, Vitest 4
- Architecture: Feature-Sliced Design (FSD) on frontend, feature-driven structure on backend
- Path alias: `@/*` → `./src/*`
- Import direction: app → pages → features → entities → shared (strict, linted by steiger)

## Files to Update

1. `.agents/skills/backend-developer-python/SKILL.md`
2. `.agents/skills/frontend-developer/SKILL.md`
3. `.agents/skills/pull-request-reviewer/SKILL.md`

## Changes Required

### 1. Backend Skill (`backend-developer-python/SKILL.md`)

**Replace** the "First Step: Discover the Backend Stack" section with a "Project Stack" section containing:

```markdown
## Project Stack (Do Not Deviate)

- **Framework**: FastAPI (async handlers, `Depends()` injection, lifespan context manager)
- **Validation**: Pydantic v2 (`BaseModel`, `field_validator`, `model_validator`, `BaseSettings` with `SettingsConfigDict`)
- **Database**: SQLAlchemy 2.0 ORM (async engine, `mapped_column`, `select()` style — NOT legacy `session.query()`)
- **Migrations**: Alembic (auto-generate from models, online + offline modes)
- **Driver**: psycopg (binary) for PostgreSQL 16
- **Testing**: pytest + FastAPI `TestClient` (sync), fixture-based setup
- **Logging**: Python stdlib `logging` with structured format
```

**Add** after Core Principles a new section "Project File Structure":

```markdown
## Project File Structure

New backend features follow this structure:

```
api/app/features/<feature_name>/
├── __init__.py
├── router.py        # APIRouter with prefix and tags
├── schemas.py       # Pydantic request/response models
├── service.py       # Business logic (no HTTP concerns)
├── repository.py    # Database queries (SQLAlchemy)
├── models.py        # SQLAlchemy ORM models
└── dependencies.py  # Depends() providers for this feature
```

- Register new routers in `api/app/api/v1/router.py`
- Settings go in `api/app/core/config.py` (Pydantic BaseSettings)
- Shared DB session management in `api/app/db/`
```

**Add** a "Stack-Specific Anti-Patterns" section:

```markdown
## Stack-Specific Anti-Patterns

Do NOT:

- Use `session.query(Model)` — use `select(Model)` (SQLAlchemy 2.0)
- Use `@validator` — use `@field_validator` (Pydantic v2)
- Use `class Config:` in Pydantic models — use `model_config = ConfigDict(...)`
- Create global DB sessions — use `Depends(get_async_session)`
- Mix sync and async DB calls in one handler
- Use `app.on_event("startup")` — use lifespan context manager
- Return `dict` from handlers — always return typed Pydantic models
- Put business logic in router handlers — delegate to service layer
```

**Remove** the generic "Python Code Quality" section (covered by AGENTS.md mandatory rules).

### 2. Frontend Skill (`frontend-developer/SKILL.md`)

**Replace** the "First Step: Discover the Frontend Stack" section with:

```markdown
## Project Stack (Do Not Deviate)

- **Framework**: React 18 + TypeScript 5.6
- **Build**: Vite 8 (path alias `@/*` → `./src/*`)
- **State**: Zustand 5 (slice composition pattern, singleton store, no Provider needed)
- **Server state**: TanStack React Query 5 (staleTime: 30s, retry: 1)
- **Routing**: React Router v7 (`createBrowserRouter`, CSR)
- **UI**: shadcn/ui components (Radix + Tailwind), design tokens
- **Validation**: Zod 4
- **Editor**: CodeMirror 6 via `@uiw/react-codemirror` wrapper
- **Persistence**: Dexie 4 (IndexedDB)
- **Charts**: Recharts
- **Icons**: lucide-react
- **Testing**: Vitest 4 + Testing Library + MSW 2 (mock service worker)
- **E2E**: Playwright 1.54
- **Package manager**: pnpm
```

**Add** a "Feature-Sliced Design Rules" section:

```markdown
## Feature-Sliced Design (FSD) Rules

Architecture layers (strict import direction, enforced by steiger linter):

```
app → pages → features → entities → shared
```

**Import rules:**
- A layer may only import from layers to its RIGHT
- `features/` CANNOT import from `pages/` or `app/`
- `entities/` CANNOT import from `features/`, `pages/`, or `app/`
- `shared/` CANNOT import from any other layer
- Cross-feature imports are FORBIDDEN (use shared or entities)

**Segment structure within each layer:**
```
<layer>/<slice>/
├── index.ts          # Public API (ONLY export from here)
├── model/            # State, types, hooks
├── ui/               # Components
├── api/              # API calls (React Query hooks, MSW handlers)
└── lib/              # Utilities specific to this slice
```

**Public API rule:** Other layers import ONLY from `<slice>/index.ts`, never from internal segments.
```

**Add** a "Zustand 5 Slice Pattern" section:

```markdown
## Zustand 5 Slice Pattern

Create slices using `StateCreator`:

```typescript
import type { StateCreator } from "zustand";
import type { MySlice } from "./types";

export const createMySlice: StateCreator<MySlice, [], [], MySlice> = (set) => ({
  myState: initialValue,
  myAction: (payload) => set((s) => ({ myState: /* transform */ })),
});
```

- Register new slices in `app/model/store.ts`
- Export slice interface type in `<feature>/model/types.ts`
- For persisted state, add fields to `app/model/persist.ts` whitelist
- Zustand store is a singleton — no React Provider needed
- In tests, store resets automatically via `afterEach` hook in `test/setup.ts`
```

**Add** a "Testing with MSW + Vitest" section:

```markdown
## Testing Pattern (Vitest + MSW 2)

```typescript
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { render, screen } from "@testing-library/react";
import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";

const server = setupServer(
  http.get("/api/v1/resource", () => HttpResponse.json({ data: [] }))
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

- Place MSW handlers near the feature: `features/<name>/api/__mocks__/handlers.ts`
- Use `renderWithProviders()` test helper if it exists, or wrap with QueryClientProvider
- Store resets automatically — do NOT manually reset Zustand in tests
- localStorage clears automatically after each test
```

**Replace** the "Avoid Generic AI UI" section with:

```markdown
## UI Implementation Rules

- Use existing shadcn/ui components from `shared/ui/` before creating custom ones
- Follow project design tokens (see `docs/design_tokens.md`)
- Use `cn()` utility from `@/shared/lib/utils` for conditional Tailwind classes
- Do not introduce new CSS frameworks, component libraries, or icon sets
- Do not use inline styles
```

### 3. PR Reviewer Skill (`pull-request-reviewer/SKILL.md`)

**Add** after "Review the Implementation Across Five Axes" a new section:

```markdown
### Stack-Specific Review Checks

**FSD Architecture:**
- [ ] No upward imports (features → app, entities → features, etc.)
- [ ] Cross-feature imports go through shared or entities, not directly
- [ ] Public API rule: imports from `<slice>/index.ts` only
- [ ] New slices registered in store composition

**Backend (FastAPI):**
- [ ] Route handlers are thin (logic in service layer)
- [ ] `Depends()` used for injection (no global state access)
- [ ] Pydantic v2 syntax (not v1 `@validator`, `class Config`)
- [ ] SQLAlchemy 2.0 style (`select()`, not `session.query()`)
- [ ] Migration included for schema changes

**Frontend (React/Zustand/Query):**
- [ ] Zustand slice uses `StateCreator` typing
- [ ] React Query keys are consistent with existing patterns
- [ ] Error/loading/empty states handled
- [ ] MSW handlers added for new API endpoints in tests

**AI-Generated Code Red Flags:**
- [ ] No phantom imports (modules that don't exist)
- [ ] No unused type definitions or dead code
- [ ] No overly verbose JSDoc on obvious functions
- [ ] No invented utility functions that duplicate existing ones
- [ ] No arbitrary abstractions for one-time operations
- [ ] Dependencies actually exist in package.json / requirements.txt
```

## Constraints

- Do NOT rename files or create new skill files
- Do NOT change the YAML frontmatter `name` field (keep existing names)
- Do NOT remove the "Instruction Priority" section from any skill
- Do NOT remove the "Completion Checklist" from any skill
- Preserve the "When to Use" sections
- Keep total file length under 250 lines per skill (trim generic advice that's already in AGENTS.md)
- Use English only
- All code examples must match the project's actual patterns (Zustand 5 StateCreator, SQLAlchemy 2.0 select(), Pydantic v2 field_validator, MSW 2 http handlers)

## Verification

After changes, verify:
1. Each skill file has valid YAML frontmatter
2. No section references tools, frameworks, or patterns the project doesn't use
3. Code examples compile/type-check against the project's dependency versions
4. Skills do not contradict AGENTS.md or CLAUDE.md
