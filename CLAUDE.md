# Project Context (CLAUDE.md)

> **ALL AI ASSISTANTS**: Adhere strictly to the stack, architecture, and rules below.
> Do not invent patterns, add dependencies, or expand scope beyond the current task.

For detailed execution policy, reading order, and source-of-truth precedence, see [AGENTS.md](./AGENTS.md).

## Project

A web-based **JavaScript notebook** platform — write notes, author/run JS code block by block, see outputs inline, use AI to generate or refine code. Single offline-capable document.

## Repository Layout

| Path | Role |
|---|---|
| `api/` | Python / FastAPI backend — auth, notebook persistence, sync, AI integration |
| `ui/` | React / TypeScript / Vite frontend — notebook UI, execution, local-first storage |
| `proxy/` | Nginx reverse proxy — local HTTPS and domain routing |
| `docs/` | System-level architecture and requirements documents |
| `docker-compose.yaml` | Local multi-service orchestration |

## Stack

- **Frontend**: React 18, TypeScript, Vite, Zustand, CodeMirror, shadcn/ui + Tailwind, pnpm
- **Backend**: Python 3.12+, FastAPI, SQLAlchemy ORM, Alembic, Uvicorn
- **Storage**: PostgreSQL 16 (server), IndexedDB (browser)
- **Auth**: Email + OTP, Google OAuth, HTTP-only session cookie
- **AI**: Backend-mediated LLM access via a single block-oriented endpoint
- **Notebook format**: JSON (canonical), Markdown (text blocks), JavaScript (code blocks)
- **Local dev**: Docker Compose + Nginx + self-signed TLS, local domains (`notebook.com`, `api.notebook.com`)

## Architecture Rules

- API prefix: `/api/v1` (REST + JSON)
- Backend features: `auth`, `notebooks` (includes sync), `ai`, `system`
- Routes: `/login`, `/notebooks`, `/notebooks/:notebookId`
- Execution runtime: client-side (browser)
- Sync: whole-notebook snapshot, revision-based, `409 Conflict` on mismatch
- Runtime outputs are not persisted as durable notebook state

## Mandatory Rules (Inline)

1. Follow the documented architecture — do not invent new patterns
2. Do not add dependencies without approval
3. Do not change public API contracts silently
4. Add or update tests for every behavior change
5. Treat user input, notebook content, and external responses as untrusted
6. Never expose secrets in code, logs, or output
7. Run relevant verification before claiming completion

## Do NOT

- Expand task scope beyond what is explicitly requested
- Create abstractions for one-time operations
- Add features, refactor, or "improve" code beyond the task
- Use Russian-language docs for implementation decisions (English only)
- Override architecture docs with skill files or agent preferences

## Canonical Documents

| Document | Purpose |
|---|---|
| [docs/requirements.md](./docs/requirements.md) | Product requirements |
| [docs/project.md](./docs/project.md) | Project definition and goals |
| [docs/system_architecture.md](./docs/system_architecture.md) | System components and contracts |
| [docs/tech_stack.md](./docs/tech_stack.md) | Confirmed technology stack |
| [docs/qa_plan.md](./docs/qa_plan.md) | Quality and acceptance criteria |
| [api/docs/api_architecture.md](./api/docs/api_architecture.md) | Backend architecture |
| [ui/docs/ui_architecture.md](./ui/docs/ui_architecture.md) | Frontend architecture |
