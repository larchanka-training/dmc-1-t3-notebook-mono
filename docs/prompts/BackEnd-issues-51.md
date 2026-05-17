# Backend Foundation Specification & Initial Implementation

This document serves as the implementation source and technical specification for the foundational layer of the enterprise-grade FastAPI application.

## 1. Project Directory Structure

```text
records-backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   └── logging.py
│   └── api/
│       ├── __init__.py
│       └── v1/
│           ├── __init__.py
│           ├── router.py
│           └── routes/
│               ├── __init__.py
│               ├── health.py
│               ├── auth/
│               │   └── __init__.py
│               ├── notebooks/
│               │   └── __init__.py
│               ├── ai/
│               │   └── __init__.py
│               └── system/
│                   └── __init__.py
├── tests/
│   ├── __init__.py
│   └── conftest.py
│   └── test_health.py
├── .env
└── .env.example
```

---

## 2. Source Code Implementation

### `app/core/config.py`
```python
from typing import Literal
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    PROJECT_NAME: str = "Enterprise Backend API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    LOG_LEVEL: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"

settings = Settings()

def get_settings() -> Settings:
    """
    Dependency provider for application configuration.
    Injects settings via FastAPI Depends to prevent global state tight-coupling.
    """
    return settings
```

### `app/core/logging.py`
```python
import logging
import sys

def setup_logging(log_level: str) -> None:
    """
    Configures standard Python logging infrastructure.
    Prepares the application layout for potential JSON log-routing structures.
    """
    root_logger = logging.getLogger()
    
    # Reset existing handlers to prevent duplicate formatting pipelines
    if root_logger.handlers:
        for handler in root_logger.handlers:
            root_logger.removeHandler(handler)

    console_handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
    )
    console_handler.setFormatter(formatter)
    
    root_logger.setLevel(getattr(logging, log_level.upper()))
    root_logger.addHandler(console_handler)

    # Suppress verbose third-party log noise
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.INFO)
```

### `app/api/v1/routes/health.py`
```python
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from app.core.config import Settings, get_settings

router = APIRouter()

class HealthCheckResponse(BaseModel):
    status: str = Field(default="healthy", description="Current operational state")
    version: str = Field(..., description="Application semantic version")
    environment: str = Field(..., description="Active runtime environment tier")

@router.get(
    "/health",
    response_model=HealthCheckResponse,
    tags=["infrastructure"],
    summary="Perform infrastructure health assessment"
)
async def perform_health_check(
    current_settings: Settings = Depends(get_settings)
) -> HealthCheckResponse:
    """
    Liveness and Readiness probe endpoint verifying configuration 
    injection and context execution lifecycle.
    """
    return HealthCheckResponse(
        status="healthy",
        version=current_settings.VERSION,
        environment=current_settings.ENVIRONMENT
    )
```

### `app/api/v1/router.py`
```python
from fastapi import APIRouter
from app.api.v1.routes import health

api_v1_router = APIRouter()

# Register initial infrastructure sub-modules
api_v1_router.include_router(health.router)

# Placeholders for future feature routes to keep boundaries clean:
# api_v1_router.include_router(auth.router, prefix="/auth", tags=["auth"])
# api_v1_router.include_router(notebooks.router, prefix="/notebooks", tags=["notebooks"])
# api_v1_router.include_router(ai.router, prefix="/ai", tags=["ai"])
# api_v1_router.include_router(system.router, prefix="/system", tags=["system"])
```

### `app/main.py`
```python
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator
from fastapi import FastAPI

from app.core.config import settings
from app.core.logging import setup_logging
from app.api.v1.router import api_v1_router

logger = logging.getLogger("app.main")

@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncGenerator[None, None]:
    """
    Manages explicit enterprise application lifecycle boundaries.
    """
    # Initialize logging prior to full runtime processing setup
    setup_logging(log_level=settings.LOG_LEVEL)
    logger.info("Application logging abstraction initialized successfully.")
    logger.info(
        f"Starting application bootstrap sequence. Context: [Environment: {settings.ENVIRONMENT}]"
    )
    
    yield
    
    logger.info("Application teardown execution completed.")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# Bind global configuration object directly into state context matrix
app.state.settings = settings

# Mount consolidated v1 router layer explicitly
app.include_router(api_v1_router, prefix=settings.API_V1_STR)
```

---

## 3. Automated Verification Testing Suite

### `tests/conftest.py`
```python
import pytest
from typing import Generator
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture(scope="module")
def client() -> Generator[TestClient, None, None]:
    """
    Generates a synchronized TestClient for integration execution loops.
    """
    with TestClient(app) as test_client:
        yield test_client
```

### `tests/test_health.py`
```python
from fastapi.testclient import TestClient
from fastapi import status
from app.core.config import settings

def test_health_check_endpoint_returns_valid_payload(client: TestClient) -> None:
    """
    Asserts compliance against infrastructure payload metadata and contract expectations.
    """
    target_url = f"{settings.API_V1_STR}/health"
    response = client.get(target_url)
    
    assert response.status_code == status.HTTP_200_OK
    
    payload = response.json()
    assert payload["status"] == "healthy"
    assert payload["version"] == settings.VERSION
    assert payload["environment"] == settings.ENVIRONMENT
```

---

## 4. Configuration Template

### `.env.example`
```env
PROJECT_NAME="Enterprise Backend API"
VERSION="1.0.0"
ENVIRONMENT="development"
LOG_LEVEL="DEBUG"
```





## 5. Implementation Delta — Changes Beyond Base Specification

This section documents all deviations and additions made during actual implementation compared to sections 1–4 above. Follow these notes to fully reproduce the resulting codebase.

---

### 5.1 Configuration Extends Base Spec

`app/core/config.py` retains the pre-existing CORS and database settings that were already in the project before this task. The final `Settings` class includes:

- `DATABASE_URL` — PostgreSQL connection string (was `database_url` in the original template)
- `BACKEND_CORS_ORIGINS` — list of allowed origins with a `field_validator` for comma-separated string parsing (was `backend_cors_origins`)
- All field names were uppercased to match Pydantic Settings convention (`app_name` → `PROJECT_NAME`, `app_env` → `ENVIRONMENT`, `api_prefix` → `API_V1_STR`)

Additional imports compared to the base spec: `Annotated`, `Any` from `typing`; `Field`, `field_validator` from `pydantic`; `NoDecode` from `pydantic_settings`.

---

### 5.2 `app/main.py` — CORS Middleware and Request Logging

The base spec does not include CORS middleware or request-level logging. The actual implementation adds:

1. **CORSMiddleware** — configured from `settings.BACKEND_CORS_ORIGINS` (carried over from the existing project).
2. **`request_logging_middleware`** — an `@app.middleware("http")` that logs every request with method, path, status code, and duration in milliseconds. Unhandled exceptions are logged with full traceback before re-raising.

Additional imports: `time`, `Request`, `Response` from `fastapi`, `CORSMiddleware` from `fastapi.middleware.cors`.

---

### 5.3 Feature-Driven Directory Structure

Per `api/docs/api_architecture.md`, the canonical backend layout uses `features/` instead of only `api/v1/routes/`. The following directories were created as empty packages (`__init__.py` only):

```text
app/
  features/
    __init__.py
    auth/__init__.py
    notebooks/__init__.py
    ai/__init__.py
    system/
      __init__.py
      router.py          ← canonical health endpoint at /system/health
  db/__init__.py
  integrations/__init__.py
```

---

### 5.4 Dual Health Endpoint Registration

The health endpoint is registered at two paths:

| Path | Source | Reason |
|---|---|---|
| `GET /api/v1/health` | `app/api/v1/routes/health.py` | Matches this spec (section 2) and backward compatibility |
| `GET /api/v1/system/health` | `app/features/system/router.py` | Canonical route per `api/docs/api_architecture.md` section 8.4 |

`app/api/v1/router.py` imports both:

```python
from app.api.v1.routes import health as legacy_health
from app.features.system.router import router as system_router

api_v1_router = APIRouter()
api_v1_router.include_router(system_router)
api_v1_router.include_router(legacy_health.router)
```

---

### 5.5 `.env.example` Extended

The actual `.env.example` includes additional variables beyond section 4:

```env
PROJECT_NAME="Backend API"
VERSION="1.0.0"
ENVIRONMENT="development"
LOG_LEVEL="DEBUG"
API_V1_STR="/api/v1"
DATABASE_URL="postgresql+psycopg://admin:admin123@postgres:5432/wiki"
BACKEND_CORS_ORIGINS="http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,https://localhost:8443"
```

---

### 5.6 Test Suite Additions

`tests/test_health.py` contains three tests instead of one:

1. `test_health_check_endpoint_returns_valid_payload` — tests `GET /api/v1/health` (matches base spec).
2. `test_system_health_endpoint_returns_valid_payload` — tests `GET /api/v1/system/health` (canonical architecture route).
3. `test_health_check_includes_cors_headers_for_allowed_origin` — verifies CORS `access-control-allow-origin` header for an allowed origin.

All tests use the `client` fixture from `conftest.py`.

---

### 5.7 `start-services.sh` Fixes

Three minimal changes were applied to the project-root `start-services.sh`:

1. `docker-compose` → `docker compose` (Docker Compose v2 CLI).
2. `name=api-1` → `name=api` and `name=frontend-1` → `name=frontend` (container name filter now matches the actual compose-generated names which include the project directory prefix).
3. Added `[ -z "$VAR" ]` guard before `docker exec` and quoted `"$API_CONTAINER"` / `"$FRONTEND_CONTAINER"` to prevent "No such container" errors when the variable is empty.

---

### 5.8 Files Created (Not in Base Spec)

| File | Purpose |
|---|---|
| `app/core/__init__.py` | Package marker (was missing) |
| `app/features/__init__.py` | Features package root |
| `app/features/auth/__init__.py` | Placeholder for auth feature |
| `app/features/notebooks/__init__.py` | Placeholder for notebooks feature |
| `app/features/ai/__init__.py` | Placeholder for AI feature |
| `app/features/system/__init__.py` | Placeholder for system feature |
| `app/features/system/router.py` | Canonical `/system/health` endpoint |
| `app/db/__init__.py` | Placeholder for shared DB infrastructure |
| `app/integrations/__init__.py` | Placeholder for external integrations |
| `tests/__init__.py` | Package marker for test discovery |

---

### 5.9 Files Preserved From Original Template

The following files existed before this task and were kept unchanged:

- `app/api/v1/endpoints/__init__.py`
- `app/api/v1/endpoints/health.py` (original simple healthcheck, superseded by `routes/health.py`)
- `alembic.ini`, `alembic/env.py`
- `pyproject.toml`, `requirements.txt`, `requirements-dev.txt`
- `Dockerfile`