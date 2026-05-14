# pytest Standards

---

## Configuration

```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = [
    "--strict-markers",   # fail on unknown markers
    "--tb=short",         # shorter tracebacks
    "-ra",                # show extra test summary for all except passed
]
markers = [
    "slow: marks tests as slow (deselect with '-m \"not slow\"')",
    "integration: marks tests as integration tests",
    "unit: marks tests as unit tests",
]

[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*", "*/__init__.py"]

[tool.coverage.report]
fail_under = 80
show_missing = true
```

```bash
# Install
pip install pytest pytest-cov pytest-asyncio

# Run all tests
pytest

# Run with coverage
pytest --cov=src --cov-report=term-missing

# Run only unit tests
pytest -m unit

# Run a specific file
pytest tests/test_user_service.py

# Run a specific test
pytest tests/test_user_service.py::TestUserService::test_get_by_id_returns_user

# Verbose output
pytest -v

# Stop on first failure
pytest -x
```

---

## Test structure

```python
# tests/test_user_service.py
import pytest
from unittest.mock import AsyncMock, patch

from src.services.user_service import UserService
from src.errors import NotFoundError, ForbiddenError


class TestUserService:
    """Tests for UserService."""

    class TestGetById:
        """Tests for UserService.get_by_id."""

        async def test_returns_user_when_found(self, user_service, mock_user):
            # Arrange — mock_user comes from conftest fixture
            # Act
            result = await user_service.get_by_id(mock_user.id)
            # Assert
            assert result.id == mock_user.id
            assert result.email == mock_user.email

        async def test_raises_not_found_when_missing(self, user_service):
            with pytest.raises(NotFoundError, match="User not found"):
                await user_service.get_by_id("nonexistent-id")

        async def test_raises_forbidden_when_not_owner(self, user_service, mock_user):
            with pytest.raises(ForbiddenError):
                await user_service.get_by_id(mock_user.id, caller_id="other-user")
```

---

## conftest.py — shared fixtures

```python
# tests/conftest.py
import pytest
from unittest.mock import AsyncMock, MagicMock

from src.repositories.user_repository import UserRepository
from src.services.user_service import UserService


# ── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture
def mock_user_repository():
    """Mock repository — isolates service from database."""
    repo = AsyncMock(spec=UserRepository)
    return repo


@pytest.fixture
def user_service(mock_user_repository):
    """UserService with a mocked repository."""
    return UserService(repository=mock_user_repository)


@pytest.fixture
def mock_user():
    """A valid user object for testing."""
    return MagicMock(
        id="user-123",
        email="test@example.com",
        name="Test User",
        role="user",
    )


# ── Database fixtures (integration tests) ───────────────────────────────────

@pytest.fixture(scope="session")
def db_engine():
    """Create a test database engine (session-scoped — one DB for all tests)."""
    from sqlalchemy import create_engine
    engine = create_engine("sqlite:///:memory:")
    # create tables...
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(db_engine):
    """Provide a transactional database session that rolls back after each test."""
    from sqlalchemy.orm import sessionmaker
    Session = sessionmaker(bind=db_engine)
    session = Session()
    session.begin_nested()     # savepoint
    yield session
    session.rollback()         # rollback to savepoint — test isolation
    session.close()
```

---

## Parametrize

```python
import pytest
from src.utils.validation import is_valid_email


@pytest.mark.parametrize("email,expected", [
    ("user@example.com",   True),
    ("user+tag@example.com", True),
    ("userexample.com",    False),   # missing @
    ("user@",              False),   # missing domain
    ("",                   False),   # empty
    (None,                 False),   # None input
], ids=[
    "valid",
    "valid-with-tag",
    "missing-at-sign",
    "missing-domain",
    "empty-string",
    "none-input",
])
def test_is_valid_email(email, expected):
    assert is_valid_email(email) == expected
```

```python
# Parametrize a class method
class TestCreateUser:
    @pytest.mark.parametrize("field,value", [
        ("email", ""),
        ("email", "not-an-email"),
        ("name",  ""),
        ("name",  "a" * 256),       # too long
    ])
    async def test_raises_validation_error_for_invalid_field(
        self, user_service, field, value
    ):
        data = {"email": "valid@example.com", "name": "Valid Name"}
        data[field] = value
        with pytest.raises(ValueError, match=field):
            await user_service.create(data)
```

---

## Async tests

```python
# Install: pip install pytest-asyncio

# pyproject.toml
# [tool.pytest.ini_options]
# asyncio_mode = "auto"   ← makes all async tests run automatically

import pytest

# With asyncio_mode = "auto", no decorator needed:
async def test_fetch_user_returns_data(user_service, mock_user):
    result = await user_service.get_by_id(mock_user.id)
    assert result is not None

# Without auto mode, use the decorator:
@pytest.mark.asyncio
async def test_fetch_user():
    result = await some_async_function()
    assert result == "expected"
```

---

## Mocking

```python
# Mocking with unittest.mock
from unittest.mock import patch, AsyncMock, MagicMock

def test_sends_email_on_registration(user_service):
    with patch("src.services.user_service.send_email") as mock_send:
        mock_send.return_value = {"message_id": "abc123"}
        user_service.register({"email": "new@example.com"})
        mock_send.assert_called_once_with(
            to="new@example.com",
            template="welcome",
        )

# Async mock
async def test_calls_external_api(http_client):
    with patch("src.clients.payment.charge") as mock_charge:
        mock_charge = AsyncMock(return_value={"status": "ok"})
        result = await process_payment(amount=100)
        assert result["status"] == "ok"
```

```python
# pytest-mock (cleaner API)
# pip install pytest-mock

def test_sends_email(user_service, mocker):
    mock_send = mocker.patch("src.services.user_service.send_email")
    mock_send.return_value = {"message_id": "abc"}
    user_service.register({"email": "new@example.com"})
    mock_send.assert_called_once()
```

---

## Markers

```python
import pytest

@pytest.mark.slow
def test_imports_large_dataset():
    # Deselect with: pytest -m "not slow"
    ...

@pytest.mark.integration
async def test_database_round_trip(db_session):
    # Run with: pytest -m integration
    ...

@pytest.mark.skip(reason="Upstream API is broken — re-enable after TICKET-123")
def test_external_payment_gateway():
    ...

@pytest.mark.xfail(reason="Known bug — see TICKET-456", strict=True)
def test_edge_case_with_known_failure():
    # strict=True: fail if it unexpectedly passes (bug was fixed without updating test)
    ...
```

---

## Coverage

```bash
# Run with coverage, show missing lines
pytest --cov=src --cov-report=term-missing

# Generate HTML report
pytest --cov=src --cov-report=html
open htmlcov/index.html

# Fail if below threshold (also configured in pyproject.toml)
pytest --cov=src --cov-fail-under=80
```

```python
# Exclude from coverage
def platform_specific():  # pragma: no cover
    # Only runs on Windows
    ...
```

---

## Test organisation

```
tests/
  conftest.py              ← shared fixtures for all tests
  unit/
    conftest.py            ← fixtures for unit tests only
    test_user_service.py
    test_order_service.py
  integration/
    conftest.py            ← DB fixtures, real HTTP client
    test_user_api.py
  e2e/
    conftest.py
    test_checkout_flow.py
```

Run only a subset:
```bash
pytest tests/unit/          # unit tests only
pytest tests/integration/   # integration tests only
pytest -m "not slow"        # exclude slow tests
```
