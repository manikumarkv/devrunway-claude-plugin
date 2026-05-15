# SQLAlchemy 2.0 Standards

## Models (Declarative, 2.0 Style)

```python
# app/models/base.py
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
```

```python
# app/models/user.py
import uuid
from datetime import datetime
from sqlalchemy import String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now(), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now(), nullable=False
    )
    is_active: Mapped[bool] = mapped_column(default=True, nullable=False)

    orders: Mapped[list["Order"]] = relationship(back_populates="user")
```

```python
# app/models/order.py
import uuid
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

class Order(Base):
    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)

    user: Mapped["User"] = relationship(back_populates="orders")
```

## Async Engine and Session

```python
# app/database.py
import os
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

DATABASE_URL = os.environ["DATABASE_URL"]  # postgresql+asyncpg://user:pass@host/db

engine = create_async_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,  # validates connections before use
    echo=False,          # set True only for debugging
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,  # prevents lazy load errors after commit
)

async def get_session() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
```

## Repository Pattern

```python
# app/repositories/user_repository.py
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.user import User

class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        stmt = select(User).where(User.id == user_id)
        return await self._session.scalar(stmt)

    async def get_by_id_with_orders(self, user_id: uuid.UUID) -> User | None:
        stmt = (
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.orders))  # eager load — avoid N+1
        )
        return await self._session.scalar(stmt)

    async def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)
        return await self._session.scalar(stmt)

    async def list_active(self, limit: int = 100, offset: int = 0) -> list[User]:
        stmt = (
            select(User)
            .where(User.is_active == True)
            .order_by(User.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await self._session.scalars(stmt)
        return list(result.all())

    async def create(self, user: User) -> User:
        self._session.add(user)
        await self._session.flush()  # flush to get DB-generated values (e.g., created_at)
        await self._session.refresh(user)
        return user

    async def delete(self, user: User) -> None:
        await self._session.delete(user)
```

## Service Layer (Unit of Work)

```python
# app/services/user_service.py
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate
from app.auth import hash_password
import uuid

class UserService:
    def __init__(self, session: AsyncSession = Depends(get_session)) -> None:
        self._session = session
        self._repo = UserRepository(session)

    async def create(self, payload: UserCreate) -> User:
        existing = await self._repo.get_by_email(payload.email)
        if existing:
            raise ValueError(f"Email {payload.email} already registered")

        user = User(
            email=payload.email,
            name=payload.name,
            password_hash=hash_password(payload.password),
        )
        user = await self._repo.create(user)
        await self._session.commit()   # single commit at end of unit of work
        return user

    async def get(self, user_id: uuid.UUID) -> User | None:
        return await self._repo.get_by_id(user_id)
```

## Raw Queries with Bound Parameters

```python
# Safe parameterized raw SQL (use only when ORM is insufficient)
from sqlalchemy import text

result = await session.execute(
    text("SELECT id, email FROM users WHERE created_at > :since"),
    {"since": since_date},
)
rows = result.fetchall()
```

## Alembic Setup

```bash
# Initialize Alembic
alembic init alembic

# alembic.ini — DATABASE_URL from environment
# sqlalchemy.url = %(DATABASE_URL)s
```

```python
# alembic/env.py — key parts
import os
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config
from alembic import context
from app.models.base import Base
# Import all models so Alembic can detect them
from app.models import user, order  # noqa: F401

config = context.config
config.set_main_option("sqlalchemy.url", os.environ["DATABASE_URL"])

target_metadata = Base.metadata

async def run_migrations_online():
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()
```

```bash
# Create a migration
alembic revision --autogenerate -m "add users table"

# Review the generated file in alembic/versions/ before applying

# Apply migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1
```

## Error Handling in Session

```python
from sqlalchemy.exc import IntegrityError

async def create_safe(session: AsyncSession, user: User) -> User | None:
    try:
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user
    except IntegrityError:
        await session.rollback()
        return None
```

## Checklist

- [ ] All models use `Mapped[T]` annotations (SQLAlchemy 2.0 style)
- [ ] `async_sessionmaker` with `expire_on_commit=False`
- [ ] `pool_pre_ping=True` on engine
- [ ] `commit()` called once per unit of work, not inside loops
- [ ] Eager loading (`selectinload`) used for relationships — no N+1
- [ ] Raw SQL uses bound parameters — no string interpolation
- [ ] Alembic `env.py` imports all models for autogenerate
- [ ] Database URL loaded from environment — not in `alembic.ini`
