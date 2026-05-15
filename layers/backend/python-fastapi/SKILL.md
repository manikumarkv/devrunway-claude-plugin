---
name: python-fastapi
description: FastAPI standards for async endpoints, Pydantic models, dependency injection, APIRouter, OpenAPI docs, and background tasks
user-invocable: false
stack: backend/python-fastapi
paths:
  - "**/*.py"
  - "**/requirements*.txt"
  - "**/pyproject.toml"
  - "**/Pipfile"
---

Full standards in [python-fastapi.md](python-fastapi.md). Always-on summary:

**Routing and structure:**
- Use `APIRouter` with `prefix` and `tags`; mount routers in `main.py` with `app.include_router()`
- Return typed response models via `response_model=` — never return raw dicts from endpoints
- Use `status_code=status.HTTP_201_CREATED` (or appropriate) on every route decorator

**Pydantic models:**
- Separate `CreateSchema`, `UpdateSchema`, and `ReadSchema`; never expose ORM models directly
- Use `model_config = ConfigDict(from_attributes=True)` for ORM serialization
- Validate at the boundary — put business logic in services, not schemas

**Dependency injection:**
- Inject DB sessions via `Depends(get_db)` — never create sessions inside route functions
- Use `Annotated[T, Depends(fn)]` syntax (FastAPI 0.95+) for cleaner signatures
- Raise `HTTPException` in dependencies; FastAPI propagates them automatically

**Async:**
- Use `async def` for all I/O-bound endpoints; use `def` for CPU-bound work (runs in threadpool)
- Never call blocking I/O (requests, psycopg2, etc.) from `async def` — use async drivers

**OpenAPI and error handling:**
- Add `summary=`, `description=`, and `responses=` to all public endpoints
- Define a global exception handler for unhandled errors; return `{"detail": ...}` envelopes

**Never:**
- Never import `app` directly in sub-modules — use `APIRouter` and mount
- Never use `Optional[X]` without a default; prefer `X | None = None` (Python 3.10+)
- Never block the event loop with `time.sleep()` — use `await asyncio.sleep()`

**Related skills:** error-handling, logging-standards, database-sql, api-conventions
