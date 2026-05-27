---
name: backend-developer-python
description: Builds and modifies backend application code, with Python as the default backend language. Use when implementing APIs, services, database models, business logic, integrations, background jobs, validation, migrations, or backend tests.
---

# Backend Developer — Python

## Overview

Build reliable, maintainable backend code using the project's Python stack. The goal is stable behavior, clear boundaries, explicit validation, predictable APIs, and testable business logic.

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

- Implementing or modifying backend APIs
- Creating service-layer business logic
- Working with database models, migrations, or queries
- Adding background jobs or scheduled tasks
- Integrating with external APIs
- Implementing authentication or authorization logic
- Adding backend validation
- Writing backend tests
- Fixing backend bugs

## Project Stack (Do Not Deviate)

- **Framework**: FastAPI (async handlers, `Depends()` injection, lifespan context manager)
- **Validation**: Pydantic v2 (`BaseModel`, `field_validator`, `model_validator`, `BaseSettings` with `SettingsConfigDict`)
- **Database**: SQLAlchemy 2.0 ORM (async engine, `mapped_column`, `select()` style — NOT legacy `session.query()`)
- **Migrations**: Alembic (auto-generate from models, online + offline modes)
- **Driver**: psycopg (binary) for PostgreSQL 16
- **Testing**: pytest + FastAPI `TestClient` (sync), fixture-based setup
- **Logging**: Python stdlib `logging` with structured format

## Core Principles

### 1. Contract First

Define the API or interface contract before implementation.

For APIs, clarify:

- Request shape
- Response shape
- Status codes
- Error format
- Authentication and authorization requirements
- Pagination/filtering behavior
- Idempotency expectations
- Backward compatibility constraints

Avoid changing existing public contracts unless the task explicitly requires it.

### 2. Validate at System Boundaries

Validate data where it enters the system:

- HTTP request bodies
- Query parameters
- Path parameters
- Environment/configuration values
- Webhook payloads
- External API responses
- Queue messages
- File imports

Internal functions may trust already-validated typed data.

External API responses are untrusted. Validate or normalize them before using them in business logic.

### 3. Keep Business Logic Out of Route Handlers

Route/controller handlers should be thin:

- Parse and validate input
- Call application/service logic
- Translate results into responses
- Handle expected errors consistently

Business rules belong in services, domain modules, or use-case functions that are easy to test without HTTP.

### 4. Use Predictable Error Semantics

Errors should be explicit and consistent.

Define clear behavior for:

- Validation errors
- Authentication failures
- Authorization failures
- Not found errors
- Conflict errors
- External service failures
- Unexpected server errors

Never expose internal stack traces, secrets, SQL errors, or implementation details to clients.

### 5. Respect Sync/Async Boundaries

Do not mix sync and async carelessly.

- Avoid blocking I/O inside async request handlers
- Use the project's existing database/session pattern
- Keep transaction boundaries explicit
- Avoid fire-and-forget tasks unless the project has a safe background execution mechanism
- Make retries and timeouts explicit for external calls

### 6. Database Changes Must Be Safe

For database work:

- Use migrations
- Preserve existing data unless explicitly instructed otherwise
- Consider backward-compatible rollout order
- Add indexes for new query patterns when needed
- Avoid unbounded queries
- Avoid N+1 query patterns
- Keep transactions as small as practical
- Make destructive changes explicit

### 7. Security Is Part of Backend Work

Check for:

- Missing authorization
- Insecure direct object references
- SQL injection
- Unsafe deserialization
- Secret leakage
- Overly broad data exposure
- Missing rate limits where abuse is plausible
- Unsafe file handling
- Trusting client-provided identity or permissions

Authentication proves who the user is. Authorization proves what they may do. Implement both where required.

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

## Testing Expectations

Add or update tests for backend behavior changes.

Useful backend tests include:

- Unit tests for business logic
- API tests for request/response behavior
- Authorization tests
- Validation tests
- Database integration tests where queries or migrations change
- Regression tests for bug fixes
- External API integration tests using mocks/fakes

Tests should verify behavior, not implementation details.

## Completion Checklist

Before considering backend work complete:

- [ ] Existing Python backend conventions were followed
- [ ] API/interface contract is explicit
- [ ] Input validation exists at system boundaries
- [ ] Authorization is handled where needed
- [ ] Error behavior is consistent with the project
- [ ] Database queries are bounded and efficient
- [ ] Migrations are included for schema changes
- [ ] External calls have timeout/error handling
- [ ] Tests were added or updated
- [ ] Lint/typecheck/test commands pass, if available
