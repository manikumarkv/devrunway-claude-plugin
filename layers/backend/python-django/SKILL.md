---
name: python-django
description: Django standards for views/URLs, ORM, migrations, DRF serializers, split settings, and management commands
user-invocable: false
stack: backend/python-django
paths:
  - "**/*.py"
  - "**/requirements*.txt"
  - "**/manage.py"
  - "**/pyproject.toml"
---

Full standards in [python-django.md](python-django.md). Always-on summary:

**Project structure:**
- Split settings into `settings/base.py`, `settings/local.py`, `settings/production.py`
- One app per domain concept — never put all models in a single `models.py` monolith
- Use `apps/` subdirectory; register apps with dotted path `apps.users.apps.UsersConfig`

**Models and ORM:**
- Always define `__str__`, `class Meta` with `ordering`, and explicit `related_name` on FK/M2M
- Use `select_related('user', 'product')` for FK traversal, `prefetch_related` for reverse/M2M — never N+1
- Wrap multi-step writes in `transaction.atomic()`; use `select_for_update()` for locking

**DRF serializers:**
- Use `ModelSerializer` with explicit `fields = [...]` — never use the magic all-fields shorthand
- Validate in `validate_<field>` or `validate()`; raise `serializers.ValidationError`
- Use `SerializerMethodField` for computed read-only fields

**Views/URLs:**
- Prefer `APIView` or `ViewSet` + `DefaultRouter` for REST endpoints
- Use `permission_classes` and `authentication_classes` explicitly per view
- Keep URL patterns in `urls.py` per app; `include()` them from the root `urls.py`

**Migrations:**
- Never edit migration files by hand; use `makemigrations --name <descriptive-name>`
- Add `db_index=True` via the model field, not raw SQL migrations
- Provide `reverse` functions in `RunPython` migrations or mark `atomic=False` carefully

**Never:**
- Never use `print()` — use `logging.getLogger(__name__)`
- Never put secrets in `settings/base.py` — use `environ` or `django-environ`
- Never use broad exception catches — always catch the specific exception type or re-raise

**Related skills:** error-handling, logging-standards, database-sql, api-conventions
