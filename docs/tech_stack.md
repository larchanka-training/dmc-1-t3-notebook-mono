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
| Backend language | `Python 3.11+` | Main backend implementation language |
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

- `React`
- `TypeScript`
- `Vite`

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

- `Python 3.11+`
- `FastAPI`
- `Pydantic Settings`
- `Uvicorn`
- `PostgreSQL`

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

The currently present development foundation includes:

- frontend linting with `ESLint`
- backend test foundation with `Pytest`
- backend API self-documentation through FastAPI OpenAPI

These are part of the current foundation, but they are not yet the full final testing and CI/CD stack.

## 11. Deferred Technology Decisions

The following technology choices are not fixed in this document yet:

| Area | Candidate options | Suggested starting point for analysis |
|---|---|---|
| Frontend state management | `React Context + useReducer`, `Zustand`, `Redux Toolkit`, `TanStack Query` for server state only | `Zustand` for notebook editor state; add `TanStack Query` only if server-state complexity grows |
| Frontend routing | `React Router`, `TanStack Router`, minimal no-router first slice | `React Router` |
| UI component layer | custom components with design tokens, `shadcn/ui`, `MUI`, `Chakra UI` | custom components plus selective `shadcn/ui` primitives |
| Charting library | `Recharts`, `Apache ECharts`, `Chart.js`, `Observable Plot` | `Recharts` for simple Version 1 charts |
| Rich text editing | plain `Markdown` textarea, `TipTap`, `Lexical` | plain `Markdown` textarea for Version 1 |
| Backend data access | `SQLAlchemy ORM`, `SQLAlchemy Core`, `SQLModel` | `SQLAlchemy ORM` or `SQLAlchemy Core` |
| Migration tool | `Alembic`, raw SQL migrations, `yoyo-migrations` | `Alembic` |
| Background jobs | no background job layer, `FastAPI BackgroundTasks`, `RQ`, `Dramatiq`, `Celery` | no dedicated job system or `FastAPI BackgroundTasks` for Version 1 |
| Email provider | `AWS SES`, `Resend`, `Postmark`, `SendGrid`, `Mailgun` | `AWS SES` or `Resend` |
| LLM provider | `OpenAI`, `Anthropic`, `AWS Bedrock`, `OpenRouter` | one primary provider behind a backend adapter |
| Frontend test stack | `Vitest + React Testing Library`, `Playwright`, `Cypress`, mixed stack | `Vitest + React Testing Library` plus a small `Playwright` smoke layer |
| CI/CD tooling | `GitHub Actions`, Docker image build pipeline, registry-based deploy pipeline, Terraform apply pipeline | `GitHub Actions` as the main CI/CD orchestrator |

These decisions should be fixed in later repo-specific architecture documents or ADRs.

## 12. Related Documents

- [project.md](./project.md)
- [projectRU.md](./projectRU.md)
- [system_architecture.md](./system_architecture.md)
- [Local-Proxy.md](./Local-Proxy.md)
