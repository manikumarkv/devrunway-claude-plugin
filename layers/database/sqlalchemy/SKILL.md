---
name: sqlalchemy
description: SQLAlchemy 2.0 — declarative models, async session, Alembic migrations, repository pattern
user-invocable: false
stack: database/sqlalchemy
paths:
  - "**/*.py"
  - "**/models/**"
  - "**/repositories/**"
  - "**/alembic/**"
  - "**/alembic.ini"
---

Full standards in [sqlalchemy.md](sqlalchemy.md). Always-on summary:

**Models:**
- Use `DeclarativeBase` (SQLAlchemy 2.0 style) — not the legacy `declarative_base()`
- Define `__tablename__` explicitly; use snake_case matching the SQL table name
- Use `Mapped[T]` type annotations with `mapped_column(...)` — they are the source of truth for column types
- Primary keys: `Mapped[uuid.UUID]` with `default=uuid.uuid4`

**Async Session:**
- Use `AsyncSession` with `async_sessionmaker` — never mix sync and async sessions
- Inject session via FastAPI dependency (`Depends(get_session)`) — never create sessions in business logic
- Call `await session.commit()` only once per unit of work — never inside loops
- Always call `await session.rollback()` in `except` blocks; use `async with` for automatic cleanup

**Queries:**
- Use `select(Model).where(...)` — not `session.query(Model)` (legacy style)
- Use `scalars().all()` for lists; `scalar_one_or_none()` for single results
- Use `selectinload(Model.relation)` for eager-loading relationships — avoid N+1 queries
- Add `index=True` to columns used in `WHERE` clauses

**Alembic Migrations:**
- Auto-generate with `alembic revision --autogenerate -m "description"` — always review before applying
- Never edit a migration that has been applied to any environment — create a new one
- Run `alembic upgrade head` in the application startup sequence (not in CI only)
- Store `alembic.ini` in source control; never commit the database URL — use env var

**Never:**
- Use `session.execute(text(...))` with string concatenation — use bound parameters
- Call `session.flush()` instead of `commit()` in request handlers
- Import models from migration files (causes circular imports with autogenerate)
- Use dynamic lazy loading for relationships — it was removed in SQLAlchemy 2.0; use `select` or `selectin` lazy instead

**Related skills:** `error-handling`, `api-conventions`, `security-principles`
