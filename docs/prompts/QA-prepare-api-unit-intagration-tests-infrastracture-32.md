# Specification: API Unit & Integration Test Infrastructure

> **Revision:** v2 — addresses review findings (auto-generated artifacts, conditional Alembic, DB dependency-override wiring, event-loop scope, test DB isolation, env loading, factory base, doc-render fixes, DoD timing baseline).

## 1. Summary

Set up the test scaffolding in `api/` so that when the first endpoint or service appears, a developer only needs to create a `test_*.py` file alongside it and immediately start writing tests. No manual fixture setup, database mocking, or Alembic migration execution required.

The default `pytest` invocation must run **only unit tests** (no Postgres required). `pytest -m integration` (or `make test-integration`) must boot the FastAPI app, apply Alembic migrations once per session, and run tests against a real PostgreSQL instance with full per-test transaction rollback.

## 2. Scope

- Test dependency management
- pytest configuration (markers, default selection, auto-generated artifacts)
- Directory structure conventions
- Base fixtures: ASGI client (with DB dependency override + FastAPI lifespan), DB session with rollback, Alembic migration runner (integration-only), authenticated user stub
- `factories.py` base class for `factory-boy` with SQLAlchemy
- Canary tests for both `unit` and `integration` markers
- Documentation in `api/README.md`
- Convenience runner (`Makefile`) so report names per marker are deterministic

## 3. Technical Requirements

### 3.1 Dependencies — `api/requirements-dev.txt`

| Package | Constraint | Purpose |
|---|---|---|
| `pytest` | `>=8.0.0,<9.0` | Test runner |
| `pytest-asyncio` | `>=0.23.0,<1.0` | Async test support (`asyncio_mode = "auto"`) |
| `pytest-cov` | `>=5.0.0` | Coverage reporting |
| `pytest-dotenv` | `>=0.5.2` | `.env.test` loader (provides the `env_files` pytest option) |
| `httpx` | `>=0.27.0` | `ASGITransport`-based async test client |
| `factory-boy` | `>=3.3.0` | Test data factories (SQLAlchemy integration) |
| `asgi-lifespan` | `>=2.1.0` | Triggers FastAPI `lifespan` events under `httpx.ASGITransport` |

> `asgi-lifespan` is required because `httpx.ASGITransport` does not invoke FastAPI's `lifespan` startup/shutdown on its own.

### 3.2 pytest Configuration — `api/pyproject.toml`

```toml
[tool.pytest.ini_options]
pythonpath = ["."]
testpaths = ["tests"]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"
env_files = [".env.test"]
markers = [
    "unit: fast, isolated tests without external services",
    "integration: tests that require PostgreSQL and run the full app stack",
]
addopts = [
    "-q",
    "--strict-markers",
    "--strict-config",
    "-m", "not integration",
    "--junitxml=reports/junit-unit.xml",
    "--cov=app",
    "--cov-branch",
    "--cov-report=term-missing",
    "--cov-report=xml:reports/coverage-unit.xml",
]
```

**Key behaviors:**

- Default `pytest` invocation runs **only unit** tests and writes `junit-unit.xml` + `coverage-unit.xml` automatically.
- `pytest -m integration` overrides the marker selection (last `-m` on CLI wins).
- To get integration-named artifacts, use `make test-integration` (§3.8), which sets `-o addopts=""` and supplies integration-specific report flags.
- `--strict-markers` / `--strict-config` prevent typos in marker and option names.
- `asyncio_default_fixture_loop_scope = "session"` is **required** so that session-scoped async fixtures (engine, migration runner) share an event loop with function-scoped ones — otherwise `pytest-asyncio>=0.23` raises `ScopeMismatch`.

### 3.3 Coverage Configuration — `api/pyproject.toml`

```toml
[tool.coverage.run]
source = ["app"]
branch = true
omit = [
    "tests/*",
    "alembic/*",
    "app/__init__.py",
]

[tool.coverage.report]
show_missing = true
skip_empty = true
exclude_also = [
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
    "pragma: no cover",
]
```

> `alembic/` is at `api/alembic/` (not under `app/`). The `omit` paths are relative to the test invocation cwd (`api/`).

### 3.4 Report Artifacts

**Output directory:** `api/reports/`

| File | When generated | Mechanism |
|---|---|---|
| `reports/junit-unit.xml` | Every default `pytest` run | `addopts` |
| `reports/coverage-unit.xml` | Every default `pytest` run | `addopts` |
| `reports/junit-integration.xml` | Every `make test-integration` run | Makefile flags |
| `reports/coverage-integration.xml` | Every `make test-integration` run | Makefile flags |

- Files are overwritten on each run (JUnit / Cobertura XML behavior). No manual cleanup needed.
- Add `reports/` to `api/.gitignore`.

### 3.5 Directory Structure

```
api/
├── tests/
│   ├── __init__.py
│   ├── conftest.py              # Shared fixtures (§3.6)
│   ├── factories.py             # factory-boy BaseFactory (§3.7)
│   ├── unit/
│   │   ├── __init__.py
│   │   └── test_canary.py
│   └── integration/
│       ├── __init__.py
│       └── test_canary.py
├── reports/                     # Generated, gitignored
├── .env.test                    # Committed; no secrets
└── Makefile                     # Test runner targets (§3.8)
```

> `__init__.py` files are intentionally kept to prevent pytest test-id collisions between `tests/unit/test_canary.py` and `tests/integration/test_canary.py`.

### 3.6 Base Fixtures — `api/tests/conftest.py`

#### 3.6.1 Marker auto-tagging by directory

```python
def pytest_collection_modifyitems(config, items):
    """Auto-apply marker based on test directory."""
    for item in items:
        path = str(item.fspath)
        if "/tests/unit/" in path and not any(m.name == "unit" for m in item.iter_markers()):
            item.add_marker(pytest.mark.unit)
        elif "/tests/integration/" in path and not any(m.name == "integration" for m in item.iter_markers()):
            item.add_marker(pytest.mark.integration)
```

> Developers don't need to remember to add `@pytest.mark.unit` / `@pytest.mark.integration` — placement determines the marker.

#### 3.6.2 Session-scoped async engine

```python
@pytest_asyncio.fixture(scope="session")
async def engine():
    """Session-scoped async engine bound to the test database."""
    from sqlalchemy.ext.asyncio import create_async_engine
    eng = create_async_engine(os.environ["TEST_DATABASE_URL"], future=True)
    yield eng
    await eng.dispose()
```

#### 3.6.3 Alembic migrations — integration only, once per session

```python
def _integration_selected(config) -> bool:
    expr = config.getoption("-m") or ""
    return "integration" in expr and "not integration" not in expr


@pytest_asyncio.fixture(scope="session")
async def apply_migrations(request):
    """
    Runs `alembic upgrade head` once before integration tests.
    NOT autouse — gated on the `-m integration` selection to keep
    default unit runs free of any Postgres dependency.
    """
    if not _integration_selected(request.config):
        yield
        return

    from alembic import command
    from alembic.config import Config

    cfg = Config("alembic.ini")
    cfg.set_main_option("sqlalchemy.url", os.environ["TEST_DATABASE_URL"])
    command.upgrade(cfg, "head")
    yield
    # Optional: command.downgrade(cfg, "base") — skipped by default for speed.
```

#### 3.6.4 Per-test DB session with rollback

```python
@pytest_asyncio.fixture
async def db_session(engine, apply_migrations) -> AsyncGenerator[AsyncSession, None]:
    """
    Per-test DB session using connection-level transaction + SAVEPOINT pattern.
    Rolls back the outer transaction in teardown, so no test data is persisted
    even if test code calls session.commit().
    """
    from sqlalchemy import event
    from sqlalchemy.ext.asyncio import AsyncSession
    from sqlalchemy.orm import sessionmaker

    async with engine.connect() as conn:
        trans = await conn.begin()
        SessionLocal = sessionmaker(
            bind=conn, class_=AsyncSession, expire_on_commit=False,
        )
        async with SessionLocal() as session:
            await session.begin_nested()

            @event.listens_for(session.sync_session, "after_transaction_end")
            def _restart_savepoint(sess, transaction):
                if transaction.nested and not transaction._parent.nested:
                    sess.begin_nested()

            try:
                yield session
            finally:
                await trans.rollback()
```

#### 3.6.5 ASGI client with lifespan and DB override

```python
@pytest_asyncio.fixture
async def client(db_session) -> AsyncGenerator[httpx.AsyncClient, None]:
    """
    Async HTTP client bound to the FastAPI app under test.
    Overrides the DB dependency to share the rollback-scoped session,
    so endpoint code participates in the same transaction as the test.
    """
    from asgi_lifespan import LifespanManager
    from app.main import app
    from app.db.session import get_db

    async def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    try:
        async with LifespanManager(app):
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=app),
                base_url="http://testserver",
            ) as ac:
                yield ac
    finally:
        app.dependency_overrides.clear()
```

> Requires `app/db/session.py::get_db` to exist as a FastAPI dependency yielding an `AsyncSession`. If absent, add a minimal stub during implementation so the override target is well-defined.

#### 3.6.6 Authenticated user stub

```python
@pytest_asyncio.fixture
async def authenticated_client(
    client: httpx.AsyncClient,
) -> AsyncGenerator[httpx.AsyncClient, None]:
    """
    HTTP client with authentication context applied.
    TODO(auth): replace stub with real session-cookie issuance
    once the auth feature lands (see api/docs/auth.md).
    """
    client.cookies.set("session", "TEST_PLACEHOLDER_SESSION")
    yield client
```

### 3.7 `tests/factories.py` — Base Factory

```python
"""
Base factory for SQLAlchemy models using factory-boy.

Usage:
    class UserFactory(BaseFactory):
        class Meta:
            model = User
        email = factory.Faker("email")
"""
from factory.alchemy import SQLAlchemyModelFactory


class BaseFactory(SQLAlchemyModelFactory):
    class Meta:
        abstract = True
        sqlalchemy_session_persistence = "flush"
        # `sqlalchemy_session` is bound at runtime via an autouse fixture
        # in conftest.py that wires the active `db_session`.
```

An autouse fixture in `conftest.py` binds `BaseFactory._meta.sqlalchemy_session = db_session` for each test that uses `db_session`. Concrete factories are added by feature owners as models appear.

### 3.8 Convenience Runner — `api/Makefile`

```makefile
.PHONY: test test-unit test-integration test-all

test: test-unit

test-unit:
	pytest

test-integration:
	pytest \
	  -o addopts="" \
	  -m integration \
	  -q --strict-markers --strict-config \
	  --junitxml=reports/junit-integration.xml \
	  --cov=app --cov-branch \
	  --cov-report=term-missing \
	  --cov-report=xml:reports/coverage-integration.xml

test-all:
	$(MAKE) test-unit
	$(MAKE) test-integration
```

> `-o addopts=""` clears the unit defaults so integration uses its own report names and marker selection without conflict.

### 3.9 Canary Tests

#### 3.9.1 Unit canary — `tests/unit/test_canary.py`

```python
async def test_canary_async():
    """pytest-asyncio auto mode works."""
    assert True


def test_canary_sync():
    """plain sync test executes."""
    assert 1 + 1 == 2
```

> Auto-tagging from §3.6.1 applies the `unit` marker — no decorator needed.

#### 3.9.2 Integration canary — `tests/integration/test_canary.py`

```python
import httpx


async def test_health_endpoint(client: httpx.AsyncClient):
    """App boots, /health returns 200 with expected payload."""
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

If `GET /health` does not exist, add a minimal route in `app/main.py`:

```python
@app.get("/health", tags=["system"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
```

### 3.10 Test Database Isolation

| Variable | Required for | Description |
|---|---|---|
| `TEST_DATABASE_URL` | integration | Async SQLAlchemy URL for a **dedicated** test database, e.g. `postgresql+psycopg://admin:admin123@localhost:5432/notebook_test` |

**Rules:**

- The integration suite must **never** connect to the dev DB (`wiki`).
- Create the dedicated test database once:
  ```bash
  docker compose up -d postgres
  docker compose exec postgres psql -U admin -c "CREATE DATABASE notebook_test;"
  ```
- `TEST_DATABASE_URL` is loaded via `pytest-env` from `api/.env.test` (committed, no secrets) or the shell environment.

**`api/.env.test`** (committed):

```dotenv
TEST_DATABASE_URL=postgresql+psycopg://admin:admin123@localhost:5432/notebook_test
ENVIRONMENT=test
LOG_LEVEL=WARNING
```

### 3.11 Documentation — `api/README.md`, "Tests" section

Add the following section (indented code blocks avoid nested-fence rendering issues):

    ## Tests

    ### Quick commands

        make test-unit          # default; ~seconds; no Postgres needed
        make test-integration   # requires docker compose postgres + notebook_test DB
        make test-all           # both, sequential

    Raw pytest equivalents:

        pytest                                    # unit only (default)
        pytest -m integration                     # integration only
        pytest -m "unit or integration"           # both

    ### Environment

    | Variable | Required for | Default source |
    |---|---|---|
    | `TEST_DATABASE_URL` | integration | `api/.env.test` (loaded by pytest-env) |

    Bring up Postgres and create the test DB once:

        docker compose up -d postgres
        docker compose exec postgres psql -U admin -c "CREATE DATABASE notebook_test;"

    ### Naming conventions

    | Kind | Path |
    |---|---|
    | Unit test | `tests/unit/<module>/test_*.py` |
    | Integration test | `tests/integration/<feature>/test_*.py` |
    | Factory | `tests/factories.py` (or `tests/factories/<feature>.py`) |

    Directory placement automatically applies the correct marker — no decorator needed.

    ### Artifacts

    All reports are written to `api/reports/` (gitignored, overwritten each run):

    | File | Produced by |
    |---|---|
    | `junit-unit.xml` | `make test-unit` |
    | `coverage-unit.xml` | `make test-unit` |
    | `junit-integration.xml` | `make test-integration` |
    | `coverage-integration.xml` | `make test-integration` |

## 4. Environment & Prerequisites

- Python 3.12+
- PostgreSQL 16 reachable on `localhost:5432` (via `docker compose up -d postgres`)
- Dedicated test database `notebook_test` created once (see §3.10)
- Virtualenv with `pip install -r requirements-dev.txt`

## 5. Definition of Done

| # | Criterion | Verification |
|---|---|---|
| 1 | `pytest` runs locally green, executes only unit canaries, **does not require Postgres** | Stop Postgres, run `pytest` → 2 unit tests pass, 0 integration collected, 0 connection errors |
| 2 | `make test-integration` runs locally green against docker-compose Postgres; Alembic applies migrations automatically | `docker compose up -d postgres && make test-integration` → canary passes; no manual `alembic upgrade` |
| 3 | Artifacts `reports/junit-unit.xml`, `reports/coverage-unit.xml`, `reports/junit-integration.xml`, `reports/coverage-integration.xml` are created automatically (no extra developer flags) | All four files exist with current timestamps after `make test-all` |
| 4 | `api/README.md` "Tests" section documents commands, env vars, conventions, artifacts | Manual review of the section |
| 5 | **Hot** wall-clock time of `make test-unit` is ≤ 30 s | `time make test-unit` after a prior warm run; excludes pip install and Docker startup |
| 6 | **Hot** wall-clock time of `make test-integration` is ≤ 60 s | `time make test-integration` after a prior warm run; excludes pip install and Docker startup |
| 7 | A new `test_dummy.py` placed under `tests/unit/` or `tests/integration/` is discovered, auto-marked, and executed with no other changes | Add a file with a single `assert True`, run the appropriate make target |

## 6. Out of Scope

- CI/CD pipeline configuration (separate task)
- Per-feature tests (added as endpoints/services land)
- `pytest-xdist` parallelization (future optimization if integration runtime grows)
- `--cov-fail-under=` coverage threshold (deferred until baseline is established)
- E2E / browser tests (owned by the UI workspace)

## 7. Implementation Checklist (for the executor)

1. Update `api/requirements-dev.txt` per §3.1.
2. Update `api/pyproject.toml` per §3.2 + §3.3.
3. Add `api/.env.test` and `api/.gitignore` entry for `reports/`.
4. Create directory structure per §3.5 (including `__init__.py` files).
5. Implement `api/tests/conftest.py` per §3.6 (all six sub-sections).
6. Implement `api/tests/factories.py` per §3.7.
7. Add `api/Makefile` per §3.8.
8. Add `app/db/session.py::get_db` if not yet present (minimal async session dependency).
9. Add `GET /health` to `app/main.py` if absent.
10. Write both canaries per §3.9.
11. Update `api/README.md` per §3.11.
12. Verify all 7 DoD items locally.
