# OpenAPI + FastAPI Standards

## App Bootstrap

```python
# main.py
from fastapi import FastAPI
from app.routers import users, orders

app = FastAPI(
    title="My Service",
    version="1.0.0",
    description="Manages users and orders.",
    contact={"name": "Platform Team", "email": "platform@example.com"},
    license_info={"name": "MIT"},
)

app.include_router(users.router)
app.include_router(orders.router)
```

## Pydantic Schemas

```python
# schemas/user.py
from pydantic import BaseModel, EmailStr, Field
from pydantic import ConfigDict
import uuid
from datetime import datetime

class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(..., min_length=1, max_length=100, description="Full display name")
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    name: str | None = Field(None, max_length=100)

class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: EmailStr
    name: str
    created_at: datetime
    # password is intentionally absent
```

## Router with Tags and Response Models

```python
# routers/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.user import UserCreate, UserRead
from app.services.user_service import UserService
from app.security import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

@router.post(
    "/",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new user",
)
async def create_user(
    payload: UserCreate,
    service: UserService = Depends(),
) -> UserRead:
    return await service.create(payload)

@router.get(
    "/{user_id}",
    response_model=UserRead,
    summary="Fetch a single user by ID",
)
async def get_user(
    user_id: uuid.UUID,
    current_user: UserRead = Depends(get_current_user),
    service: UserService = Depends(),
) -> UserRead:
    user = await service.get(user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
```

## Security Scheme

```python
# security.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.auth import verify_token

bearer = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    payload = verify_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload
```

```python
# Attach security to an entire router
router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
    dependencies=[Depends(get_current_user)],
)
```

## Error Responses in Spec

```python
from fastapi import Request
from fastapi.responses import JSONResponse

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": str(exc)},
    )
```

## Versioning

- Use URL prefix versioning: `/v1/`, `/v2/` — mount separate `FastAPI` apps via `Mount` for major breaks
- Minor additions are non-breaking — add optional fields, new routes
- Never remove or rename fields in a published version without a major bump

## Spec Export for CI

```bash
# Generate static openapi.json for linting / contract tests
python -c "
import json
from app.main import app
print(json.dumps(app.openapi(), indent=2))
" > openapi.json

# Lint with Spectral
npx @stoplight/spectral-cli lint openapi.json --ruleset .spectral.yaml
```

## Checklist

- [ ] All routes have `response_model`, `status_code`, and `summary`
- [ ] Separate `Create` / `Update` / `Read` schemas for every resource
- [ ] Passwords and internal fields excluded from `Read` schemas
- [ ] Security dependency applied at router level, not scattered across endpoints
- [ ] `openapi.json` exported and linted in CI

## Common mistakes

| Mistake | Fix |
|---|---|
| Using a single Pydantic model for create, update, and read | Define separate `UserCreate`, `UserUpdate`, and `UserRead` schemas; they differ in required fields and which fields are exposed |
| Leaving `password` or internal fields in the `Read` schema | Explicitly exclude sensitive fields from response schemas by omitting them — FastAPI serializes only what the model declares |
| Not setting `response_model` on route handlers | Without `response_model`, FastAPI returns the raw ORM object and may expose internal fields; always declare the expected response schema |
| Applying security dependencies per-endpoint instead of per-router | Add `dependencies=[Depends(get_current_user)]` at the `APIRouter` level so no endpoint in that group is accidentally left open |
| Mixing validation errors with HTTP exceptions | Use `HTTPException` for HTTP-level errors (404, 401) and Pydantic `ValidationError` / `raise RequestValidationError` for input errors — keep them separate |
| Not exporting `openapi.json` and linting it in CI | Without CI validation, breaking schema changes (renamed fields, removed endpoints) ship silently; export and run Spectral on every PR |
| Using `str` instead of `uuid.UUID` for IDs in path parameters | Declaring `user_id: uuid.UUID` lets FastAPI validate format automatically and documents the type in the OpenAPI spec |
| Missing `status_code` on POST endpoints | FastAPI defaults to `200`; POST endpoints that create resources should return `201` — set `status_code=status.HTTP_201_CREATED` |
