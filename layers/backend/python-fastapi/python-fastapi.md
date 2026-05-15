# FastAPI Standards

## Project structure

```
app/
├── main.py              # App factory, middleware, router mounting
├── dependencies.py      # Shared Depends() functions
├── config.py            # Settings via pydantic-settings
├── database.py          # SQLAlchemy engine + session factory
├── routers/
│   ├── users.py
│   └── items.py
├── schemas/
│   ├── user.py
│   └── item.py
├── models/
│   ├── user.py          # SQLAlchemy ORM models
│   └── item.py
└── services/
    ├── user_service.py
    └── item_service.py
```

## App factory — `main.py`

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.routers import users, items


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # shutdown
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(items.router, prefix="/api/v1")


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    import logging
    logging.getLogger(__name__).exception("Unhandled error")
    from fastapi.responses import JSONResponse
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})
```

## Settings — `config.py`

```python
from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "MyApp"
    database_url: str
    cors_origins: list[str] = ["http://localhost:3000"]
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
```

## Database session — `database.py`

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine = create_async_engine(settings.database_url, echo=False, pool_pre_ping=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

## Dependencies — `dependencies.py`

```python
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
import jwt

from app.database import get_db
from app.config import settings
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

DbSession = Annotated[AsyncSession, Depends(get_db)]


async def get_current_user(
    token: Annotated[str, Depends(oauth2_scheme)],
    db: DbSession,
) -> User:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exc
    except jwt.PyJWTError:
        raise credentials_exc

    user = await db.get(User, int(user_id))
    if user is None:
        raise credentials_exc
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
```

## Pydantic schemas — `schemas/user.py`

```python
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict, field_validator


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    full_name: str
    is_active: bool
    created_at: datetime


class UserList(BaseModel):
    items: list[UserRead]
    total: int
    page: int
    page_size: int
```

## ORM model — `models/user.py`

```python
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )
```

## Service layer — `services/user_service.py`

```python
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
import bcrypt

from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


async def create_user(db: AsyncSession, data: UserCreate) -> User:
    existing = await db.scalar(select(User).where(User.email == data.email))
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Email already registered")

    hashed = bcrypt.hashpw(data.password.encode(), bcrypt.gensalt()).decode()
    user = User(email=data.email, full_name=data.full_name, hashed_password=hashed)
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


async def get_users(db: AsyncSession, page: int = 1, page_size: int = 20) -> tuple[list[User], int]:
    offset = (page - 1) * page_size
    total = await db.scalar(select(func.count()).select_from(User))
    result = await db.scalars(select(User).offset(offset).limit(page_size))
    return result.all(), total or 0


async def update_user(db: AsyncSession, user_id: int, data: UserUpdate) -> User:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="User not found")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)

    await db.flush()
    await db.refresh(user)
    return user
```

## Router — `routers/users.py`

```python
from typing import Annotated
from fastapi import APIRouter, Depends, status, BackgroundTasks, Query

from app.dependencies import DbSession, CurrentUser
from app.schemas.user import UserCreate, UserRead, UserUpdate, UserList
from app.services import user_service
from app.tasks import send_welcome_email

router = APIRouter(prefix="/users", tags=["users"])


@router.post(
    "/",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
    responses={409: {"description": "Email already registered"}},
)
async def create_user(
    data: UserCreate,
    db: DbSession,
    background_tasks: BackgroundTasks,
):
    user = await user_service.create_user(db, data)
    background_tasks.add_task(send_welcome_email, user.email, user.full_name)
    return user


@router.get(
    "/",
    response_model=UserList,
    summary="List users (paginated)",
)
async def list_users(
    db: DbSession,
    _: CurrentUser,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    users, total = await user_service.get_users(db, page, page_size)
    return UserList(items=users, total=total, page=page, page_size=page_size)


@router.get("/me", response_model=UserRead, summary="Get current user")
async def get_me(current_user: CurrentUser):
    return current_user


@router.patch("/{user_id}", response_model=UserRead, summary="Update user")
async def update_user(
    user_id: int,
    data: UserUpdate,
    db: DbSession,
    _: CurrentUser,
):
    return await user_service.update_user(db, user_id, data)
```

## Background tasks

```python
# app/tasks.py
import asyncio
import logging

logger = logging.getLogger(__name__)


async def send_welcome_email(email: str, full_name: str) -> None:
    """Background task — runs after response is sent."""
    try:
        # e.g. await ses_client.send_email(...)
        logger.info("welcome_email_sent", extra={"email": email})
    except Exception:
        logger.exception("welcome_email_failed", extra={"email": email})
```

## Pagination query params — reusable dependency

```python
from dataclasses import dataclass
from fastapi import Query


@dataclass
class PaginationParams:
    page: int = Query(1, ge=1)
    page_size: int = Query(20, ge=1, le=100)


Pagination = Annotated[PaginationParams, Depends(PaginationParams)]
```

## Custom exception classes

```python
# app/exceptions.py
from fastapi import HTTPException, status


class NotFoundError(HTTPException):
    def __init__(self, resource: str, resource_id: int | str):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"{resource} {resource_id} not found",
        )


class ConflictError(HTTPException):
    def __init__(self, detail: str):
        super().__init__(status_code=status.HTTP_409_CONFLICT, detail=detail)


class ForbiddenError(HTTPException):
    def __init__(self):
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
```

## Testing with pytest-asyncio

```python
# tests/conftest.py
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.main import app
from app.database import Base, get_db

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture
async def db_session():
    engine = create_async_engine(TEST_DATABASE_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    AsyncTestSession = async_sessionmaker(engine, expire_on_commit=False)
    async with AsyncTestSession() as session:
        yield session
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session):
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


# tests/test_users.py
async def test_create_user(client):
    response = await client.post("/api/v1/users/", json={
        "email": "test@example.com",
        "password": "securepassword",
        "full_name": "Test User",
    })
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "hashed_password" not in data
```

## Common mistakes

| Mistake | Fix |
|---|---|
| `async def` endpoint calling `requests.get()` | Use `httpx.AsyncClient` or `aiohttp` |
| Returning ORM model directly | Always use `response_model=` with a Pydantic schema |
| Creating `Session()` inside route | Use `Depends(get_db)` so session lifecycle is managed |
| `Optional[X]` import from `typing` | Use `X | None = None` (Python 3.10+) |
| No `await session.commit()` | Commit in the `get_db` dependency, not in each route |
| Global `app` imported into sub-routers | Use `APIRouter`; never import `app` in sub-modules |
| Background task blocks event loop | Background tasks run in a threadpool if `def`; use `async def` for async I/O |
| Missing `status_code` on POST | Always specify `status_code=status.HTTP_201_CREATED` for resource creation |
