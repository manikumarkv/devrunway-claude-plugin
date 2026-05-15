---
name: pytest
description: pytest conventions — fixtures, conftest.py, parametrize, markers, async tests, and coverage. Load when working with pytest test files or pyproject.toml test configuration.
user-invocable: false
stack: testing/unit/pytest
paths:
  - "conftest.py"
  - "**/conftest.py"
  - "pytest.ini"
  - "pyproject.toml"
  - "**/test_*.py"
  - "**/*_test.py"
---

Full standards in [pytest.md](pytest.md). Always-on summary:

**File and function naming:**
- Files: `test_<module>.py` (prefix, not suffix) — pytest discovers these automatically
- Functions: `def test_<behaviour>()` — describe the behaviour, not the method
- Classes: `class TestUserService:` — group related tests; no `__init__` method

**Fixtures:**
- Declare with `@pytest.fixture` decorator in `conftest.py` — pytest injects them automatically by parameter name
- Use the narrowest scope needed: `function` (default) → `class` → `module` → `session`
- Yield fixtures for setup/teardown: `yield` provides the value; cleanup runs after

**Parametrize:**
- `@pytest.mark.parametrize` for testing multiple inputs — never copy-paste tests
- Use `ids=` for readable test names in the output

**Assertions:**
- Plain `assert` statements — pytest rewrites them for detailed output; e.g., `assert response.status_code == 200`
- `pytest.raises(ExcType)` for exception testing — use as context manager
- `pytest.approx()` for floating-point comparisons

**Output capture:**
- Use the `capsys` fixture to capture and assert on stdout/stderr — never write raw stdout in tests

**Never:**
- `unittest.TestCase` style in new pytest code — use plain functions and fixtures
- Raw stdout debugging — use `pytest -s` flag or proper logging
- Skip tests without a reason: `@pytest.mark.skip(reason='...')` required

**Related skills:** `backend/python-fastapi` (pytest-asyncio, TestClient), `database/sqlalchemy` (session fixture patterns)
