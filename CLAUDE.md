# CLAUDE

This file is the main entry point for Claude agents working in this repository.

## Agent Bootstrap

For AI agent execution context, required reading order, source-of-truth precedence, and mandatory execution rules, see:

- [AGENTS.md](./AGENTS.md)

## Project Summary

A web-based **JavaScript notebook** platform. Users write notes, author and run JavaScript code block by block, see outputs inline, and use AI to generate or refine code — all in a single offline-capable document.

## Repository Layout

| Path | Role |
|---|---|
| `api/` | Python / FastAPI backend — auth, notebook persistence, sync, AI integration |
| `ui/` | React / TypeScript / Vite frontend — notebook UI, execution, local-first storage |
| `proxy/` | Nginx reverse proxy — local HTTPS and domain routing |
| `docs/` | System-level architecture and requirements documents |
| `docker-compose.yaml` | Local multi-service orchestration |

## Key Technology Decisions

- **Frontend**: React, TypeScript, Vite, Zustand, CodeMirror, shadcn/ui + Tailwind, pnpm
- **Backend**: Python 3.12+, FastAPI, SQLAlchemy ORM, Alembic, Uvicorn
- **Storage**: PostgreSQL 16 (server), IndexedDB (browser)
- **Auth**: Email + OTP, Google OAuth, HTTP-only session cookie
- **AI**: Backend-mediated LLM access via a single block-oriented endpoint
- **Notebook format**: JSON (canonical), Markdown (text blocks), JavaScript (code blocks)
- **Local dev**: Docker Compose + Nginx + self-signed TLS, local domains (`notebook.com`, `api.notebook.com`)

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

## Fixed Architecture Rules (Version 1)

- API prefix: `/api/v1` (REST + JSON)
- Backend features: `auth`, `notebooks` (includes sync), `ai`, `system`
- Routes: `/login`, `/notebooks`, `/notebooks/:notebookId`
- Execution runtime: client-side (browser)
- Sync: whole-notebook snapshot, revision-based, `409 Conflict` on mismatch
- Runtime outputs are not persisted as durable notebook state
