# Technology Stack

## 1. Purpose

This document fixes the confirmed technology stack of the project at system level.

It describes:

- technologies already selected for the project
- the role of each selected technology
- technology boundaries between frontend, backend, storage, runtime, and integrations
- technology decisions that are still intentionally deferred

## 2. Project-Level Stack

| Area | Technology | Role |
|---|---|---|
| Application delivery model | `Hosted web application with local-first behavior` | Browser-delivered product with client-side execution and server-side control, storage, and integrations |
| Frontend language | `TypeScript` | Main frontend implementation language |
| Frontend framework | `React` | Notebook user interface |
| Frontend build tool | `Vite` | Frontend development server and build pipeline |
| Backend language | `Python 3.12+` | Main backend implementation language |
| Backend framework | `FastAPI` | HTTP API layer |
| Backend configuration | `Pydantic Settings` | Environment-based configuration |
| Backend server | `Uvicorn` | ASGI application server |
| Database | `PostgreSQL` | Durable server-side storage |
| Local persistence | `IndexedDB` | Browser-side persistent working copy |
| Reverse proxy | `Nginx` | Local HTTPS and local domain routing |
| Local orchestration | `Docker Compose` | Local multi-service startup |
| DB administration | `pgAdmin` | Local database inspection and administration |
| Notebook content format | `JSON` | Canonical notebook storage and sync format |
| Text block format | `Markdown` | Text block content format |
| Code block format | `JavaScript` | Executable notebook code format |
| API exchange format | `HTTP + JSON` | Frontend-backend communication |
| Authentication method | `Email + OTP`, `Google OAuth` | Version 1 sign-in flows |
| Auth client state | `Secure HTTP-only session cookie` | Browser auth state managed through backend session |
| External identity provider | `Google OAuth` | Third-party browser sign-in |
| AI access path | `Backend-mediated LLM access` | LLM requests pass through backend |

## 3. Frontend Stack

The confirmed frontend stack is:

- `React 18`
- `TypeScript 5.6`
- `Vite 8`
- `Zustand 5` (global state, slice composition pattern)
- `TanStack React Query 5` (server state)
- `React Router v7` (client-side routing, `createBrowserRouter`)
- `shadcn/ui` + `Radix UI` + `Tailwind CSS 3` (component layer)
- `Zod 4` (schema validation)
- `CodeMirror 6` via `@uiw/react-codemirror` (code block editor)
- `Dexie 4` (IndexedDB local persistence)
- `Recharts` (charting)
- `lucide-react` (icons)
- `pnpm` (package manager)
- `Vitest 4` + `React Testing Library` (unit and component tests)
- `MSW 2` (API mocking in tests)
- `Playwright 1.54` (end-to-end tests)
- `steiger` (FSD architecture linting)

The frontend is responsible for:

- browser-delivered application shell
- notebook UI
- block editing
- execution UI
- sync UI
- AI request UI
- local persistence integration

The frontend also owns:

- the active working copy of notebooks during editing
- browser-side local persistence
- client-side execution orchestration

## 4. Backend Stack

The confirmed backend stack is:

- `Python 3.12+`
- `FastAPI`
- `Pydantic v2` and `Pydantic Settings`
- `SQLAlchemy 2.0 ORM` (async engine, `select()` style)
- `Alembic` (schema migrations)
- `psycopg (binary) v3` (PostgreSQL 16 async driver)
- `Uvicorn`
- `PostgreSQL 16`
- `pytest` + `FastAPI TestClient` (backend tests)

The backend is responsible for:

- authentication
- OTP issuance and verification
- Google OAuth handling
- notebook persistence
- sync endpoints
- access control
- AI integration endpoints
- health and operational endpoints

## 5. Persistence and Data Formats

The confirmed persistence and data format choices are:

- durable server-side storage: `PostgreSQL`
- browser-side local persistence: `IndexedDB`
- notebook format: structured `JSON`
- text block format: `Markdown`
- code block format: executable `JavaScript`
- synchronization payload format: `JSON`
- export format for Version 1: portable notebook `JSON`

## 6. Runtime and Execution Technologies

The confirmed execution technology choices are:

- executable notebook language: `JavaScript`
- execution location for Version 1: `client-side`
- execution control location: `frontend-side execution orchestrator`
- application delivery surface: browser-hosted web application

The execution runtime remains a distinct architectural part even though it is client-side.

## 7. Authentication and Security Technologies

The confirmed authentication and security choices are:

- sign-in methods: `Email + OTP`, `Google OAuth`
- authenticated browser state after email or Google sign-in: backend-managed secure `HTTP-only` session cookie
- OTP delivery: external email delivery service
- external identity provider: `Google OAuth`
- access control enforcement: backend-side
- AI provider credentials: backend-side
- notebook code trust level: untrusted
- AI-generated code trust level: untrusted

## 8. AI Integration Technologies

The confirmed AI integration choices are:

- AI requests are initiated from the frontend
- AI provider access goes through the backend
- AI returns code for a selected notebook block
- returned AI code becomes normal editable notebook content after insertion

This means the project does not use direct browser-to-provider LLM access in Version 1.

## 9. Local Development Tooling

The confirmed local development tooling is:

- `Docker Compose`
- `Nginx`
- `PostgreSQL`
- `pgAdmin`

Local domains:

- `notebook.com`
- `api.notebook.com`
- `pgadmin.notebook.com`

## 10. Quality and Development Foundation

The confirmed quality and development foundation includes:

- frontend linting with `ESLint`; FSD architecture linting with `steiger`
- frontend unit and component tests with `Vitest 4` + `React Testing Library`
- frontend API mocking in tests with `MSW 2`
- end-to-end tests with `Playwright 1.54`
- backend tests with `pytest` + `FastAPI TestClient`
- backend API self-documentation through FastAPI OpenAPI

CI/CD tooling is not yet fixed (see Section 11).

## 11. Deferred Technology Decisions

The following technology choices are not fixed in this document yet:

| Area | Candidate options | Suggested starting point for analysis |
|---|---|---|
| Rich text editing | plain `Markdown` textarea, `TipTap`, `Lexical` | plain `Markdown` textarea for Version 1 |
| Background jobs | no background job layer, `FastAPI BackgroundTasks`, `RQ`, `Dramatiq`, `Celery` | no dedicated job system or `FastAPI BackgroundTasks` for Version 1 |
| Email provider | `AWS SES`, `Resend`, `Postmark`, `SendGrid`, `Mailgun` | `AWS SES` or `Resend` |
| LLM provider | `OpenAI`, `Anthropic`, `AWS Bedrock`, `OpenRouter` | one primary provider behind a backend adapter |
| CI/CD tooling | `GitHub Actions`, Docker image build pipeline, registry-based deploy pipeline, Terraform apply pipeline | `GitHub Actions` as the main CI/CD orchestrator |

These decisions should be fixed in later repo-specific architecture documents or ADRs.

## 12. Related Documents

- [project.md](./project.md)
- [projectRU.md](./projectRU.md)
- [system_architecture.md](./system_architecture.md)
- [Local-Proxy.md](./Local-Proxy.md)
