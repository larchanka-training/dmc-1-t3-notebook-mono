---
name: frontend-developer
description: Builds and modifies frontend application code. Use when implementing UI, client-side behavior, frontend data flows, forms, layouts, accessibility, or integration with backend APIs. The frontend stack may be unknown, so inspect the project before assuming React, Vue, Angular, Svelte, Tailwind, or any design system.
---

# Frontend Developer

## Overview

Build production-quality frontend code that fits the existing project. Do not assume the frontend framework, styling system, routing model, state library, or build tool until the repository has been inspected.

The goal is not to produce a visually impressive generic UI. The goal is to implement maintainable, accessible, tested frontend behavior that matches the product requirements and the codebase conventions.

## Instruction Priority

Project-specific instructions have higher priority than this skill.

When working in a repository, always check and follow:

1. `AGENTS.md`
2. Canonical project documentation
3. Existing codebase conventions
4. This skill

If this skill conflicts with `AGENTS.md`, canonical documentation, or established repository patterns, follow the project-specific source instead.

## When to Use

Use this skill when:

- Building or modifying user-facing interfaces
- Creating or updating frontend components
- Implementing forms, tables, filters, navigation, modals, or dashboards
- Integrating frontend code with backend APIs
- Managing client-side state or server state
- Fixing frontend bugs
- Improving accessibility, responsiveness, loading states, or error states

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

## Core Principles

### 1. Follow Existing Conventions

Match the repository's patterns before introducing new ones.

Prefer:

- Existing components over new custom components
- Existing design tokens over raw colors or arbitrary spacing
- Existing hooks/utilities over duplicate logic
- Existing API client patterns over ad hoc fetch calls
- Existing test style over a new testing approach

If a new pattern is necessary, keep it small, explicit, and documented by the code structure.

### 2. Separate Data, State, and Presentation

Keep responsibilities clear:

- API/client layer fetches or mutates remote data
- Hooks or containers coordinate data and UI state
- Components render UI and receive clear props
- Utility functions stay pure where possible

Avoid mixing network calls, formatting, validation, and rendering in one large component.

### 3. Prefer Composition Over Over-Configuration

Prefer small composable components instead of components with many boolean flags and variant props.

Good frontend code should make common use cases simple and unusual use cases explicit.

### 4. Design for Real States

Every user-facing flow should handle:

- Loading state
- Empty state
- Error state
- Success state
- Disabled/submitting state
- Permission or unavailable state, where relevant

Do not leave blank screens or silent failures.

### 5. Accessibility Is Required

Frontend work must be accessible by default:

- Use semantic HTML first
- Interactive elements must be keyboard-accessible
- Inputs must have labels
- Icon-only buttons must have accessible names
- Focus should be managed for dialogs, menus, and dynamic content
- Do not rely only on color to communicate meaning
- Preserve logical heading order
- Ensure reasonable color contrast

Prefer native HTML behavior over custom ARIA-heavy implementations.

### 6. Responsive Behavior Must Be Intentional

Implement layouts that work across relevant viewport sizes. At minimum, check:

- Small mobile width
- Tablet width
- Desktop width
- Wide desktop width, if the product uses dense layouts

Do not assume fixed desktop-only layouts unless the product explicitly requires them.

### 7. UI Implementation Rules

- Use existing shadcn/ui components from `shared/ui/` before creating custom ones
- Follow project design tokens (see `docs/design_tokens.md`)
- Use `cn()` utility from `@/shared/lib/utils` for conditional Tailwind classes
- Do not introduce new CSS frameworks, component libraries, or icon sets
- Do not use inline styles

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

## API Integration

When integrating with backend APIs:

- Use existing API clients or request helpers
- Validate assumptions about response shape
- Handle API errors consistently
- Keep request/response types close to the API layer
- Avoid leaking raw backend errors directly into UI
- Support pagination, filtering, and optimistic updates only when required

External data should be treated as untrusted until validated or normalized.

## Testing Expectations

Add or update tests when behavior changes.

Prefer tests that verify user-visible behavior:

- Component renders the expected state
- User interaction triggers the correct result
- Form validation blocks invalid input
- Loading/error/empty states render correctly
- API integration handles success and failure paths

Avoid tests that only assert implementation details.

## Completion Checklist

Before considering frontend work complete:

- [ ] Existing stack and conventions were followed
- [ ] UI handles loading, empty, error, and success states
- [ ] Interactive elements are accessible by keyboard
- [ ] Form fields and controls are properly labeled
- [ ] Responsive behavior was considered
- [ ] API errors are handled consistently
- [ ] Tests were added or updated where appropriate
- [ ] Build/lint/typecheck/test commands pass, if available
