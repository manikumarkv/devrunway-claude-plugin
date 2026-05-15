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
