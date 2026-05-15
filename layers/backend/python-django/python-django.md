# Django Standards

## Project layout

```
project/
├── manage.py
├── config/
│   ├── settings/
│   │   ├── base.py
│   │   ├── local.py
│   │   └── production.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── apps/
│   ├── users/
│   │   ├── apps.py
│   │   ├── models.py
│   │   ├── serializers.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   ├── admin.py
│   │   ├── services.py
│   │   └── tests/
│   └── items/
└── requirements/
    ├── base.txt
    ├── local.txt
    └── production.txt
```

## Settings split

```python
# config/settings/base.py
from pathlib import Path
import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent
env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env")

SECRET_KEY = env("DJANGO_SECRET_KEY")
DEBUG = env.bool("DJANGO_DEBUG", default=False)
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=[])

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third-party
    "rest_framework",
    "corsheaders",
    # Local
    "apps.users.apps.UsersConfig",
    "apps.items.apps.ItemsConfig",
]

DATABASES = {
    "default": env.db("DATABASE_URL")
}

AUTH_USER_MODEL = "users.User"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
}
```

```python
# config/settings/production.py
from .base import *  # noqa: F403

DEBUG = False
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
```

## Custom user model

```python
# apps/users/models.py
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models


class UserManager(BaseUserManager):
    def create_user(self, email: str, password: str, **extra_fields):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=255)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["full_name"]

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.email
```

## DRF Serializers

```python
# apps/users/serializers.py
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from apps.users.models import User


class UserCreateSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "full_name", "password", "password_confirm"]

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email already registered.")
        return value

    def validate(self, attrs: dict) -> dict:
        if attrs["password"] != attrs.pop("password_confirm"):
            raise serializers.ValidationError({"password_confirm": "Passwords do not match."})
        validate_password(attrs["password"])
        return attrs

    def create(self, validated_data: dict) -> User:
        return User.objects.create_user(**validated_data)


class UserReadSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "email", "full_name", "is_active", "created_at"]
        read_only_fields = fields


class UserUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["full_name", "email"]

    def update(self, instance: User, validated_data: dict) -> User:
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance
```

## ViewSets and routers

```python
# apps/users/views.py
from rest_framework import viewsets, status, mixins
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from apps.users.models import User
from apps.users.serializers import UserCreateSerializer, UserReadSerializer, UserUpdateSerializer


class UserViewSet(
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    queryset = User.objects.all().order_by("-created_at")
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action == "create":
            return [AllowAny()]
        return super().get_permissions()

    def get_serializer_class(self):
        if self.action == "create":
            return UserCreateSerializer
        if self.action in ("update", "partial_update"):
            return UserUpdateSerializer
        return UserReadSerializer

    @action(detail=False, methods=["get"], url_path="me")
    def me(self, request: Request) -> Response:
        serializer = UserReadSerializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=["patch"], url_path="me/update")
    def update_me(self, request: Request) -> Response:
        serializer = UserUpdateSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserReadSerializer(request.user).data)
```

```python
# apps/users/urls.py
from rest_framework.routers import DefaultRouter
from apps.users.views import UserViewSet

router = DefaultRouter()
router.register("users", UserViewSet, basename="user")

urlpatterns = router.urls
```

```python
# config/urls.py
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("apps.users.urls")),
    path("api/v1/", include("apps.items.urls")),
    path("api/v1/auth/", include("rest_framework_simplejwt.urls")),
]
```

## ORM patterns — avoiding N+1

```python
# BAD — N+1
for order in Order.objects.all():
    print(order.user.email)  # extra query per row

# GOOD — select_related for FK
for order in Order.objects.select_related("user").all():
    print(order.user.email)  # no extra queries

# GOOD — prefetch_related for M2M / reverse FK
for user in User.objects.prefetch_related("orders").all():
    for order in user.orders.all():  # uses prefetch cache
        print(order.id)

# Annotations instead of Python aggregation
from django.db.models import Count, Sum
User.objects.annotate(order_count=Count("orders")).filter(order_count__gt=5)
```

## Transactions

```python
from django.db import transaction


def transfer_credits(from_user_id: int, to_user_id: int, amount: int) -> None:
    with transaction.atomic():
        sender = User.objects.select_for_update().get(id=from_user_id)
        recipient = User.objects.select_for_update().get(id=to_user_id)

        if sender.credits < amount:
            raise ValueError("Insufficient credits")

        sender.credits -= amount
        recipient.credits += amount

        sender.save(update_fields=["credits"])
        recipient.save(update_fields=["credits"])
```

## Migrations best practices

```bash
# Always name migrations descriptively
python manage.py makemigrations --name add_user_avatar_field

# Check SQL before applying
python manage.py sqlmigrate users 0003

# Squash when >20 migrations in an app
python manage.py squashmigrations users 0001 0020
```

```python
# Data migration with reversible RunPython
from django.db import migrations


def populate_full_name(apps, schema_editor):
    User = apps.get_model("users", "User")
    for user in User.objects.all():
        user.full_name = f"{user.first_name} {user.last_name}".strip()
        user.save(update_fields=["full_name"])


def reverse_populate_full_name(apps, schema_editor):
    pass  # safe no-op for reversal


class Migration(migrations.Migration):
    dependencies = [("users", "0002_user_full_name")]

    operations = [
        migrations.RunPython(populate_full_name, reverse_code=reverse_populate_full_name),
    ]
```

## Admin registration

```python
# apps/users/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from apps.users.models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ["email", "full_name", "is_active", "created_at"]
    list_filter = ["is_active", "is_staff"]
    search_fields = ["email", "full_name"]
    ordering = ["-created_at"]
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Personal info", {"fields": ("full_name",)}),
        ("Permissions", {"fields": ("is_active", "is_staff", "is_superuser", "groups")}),
    )
    add_fieldsets = (
        (None, {"fields": ("email", "full_name", "password1", "password2")}),
    )
```

## Management commands

```python
# apps/users/management/commands/deactivate_stale_users.py
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.users.models import User
import logging

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Deactivate users who have not logged in for 90 days"

    def add_arguments(self, parser):
        parser.add_argument("--days", type=int, default=90)
        parser.add_argument("--dry-run", action="store_true")

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(days=options["days"])
        qs = User.objects.filter(last_login__lt=cutoff, is_active=True)
        count = qs.count()

        if options["dry_run"]:
            self.stdout.write(f"[dry-run] Would deactivate {count} users")
            return

        qs.update(is_active=False)
        logger.info("stale_users_deactivated", extra={"count": count})
        self.stdout.write(self.style.SUCCESS(f"Deactivated {count} users"))
```

## Testing with pytest-django

```python
# pytest.ini / pyproject.toml
# [tool.pytest.ini_options]
# DJANGO_SETTINGS_MODULE = "config.settings.local"
# python_files = "tests.py test_*.py *_tests.py"

# apps/users/tests/test_views.py
import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from apps.users.models import User


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def user(db):
    return User.objects.create_user(
        email="test@example.com",
        password="testpassword",
        full_name="Test User",
    )


@pytest.fixture
def auth_client(api_client, user):
    api_client.force_authenticate(user=user)
    return api_client


@pytest.mark.django_db
def test_create_user(api_client):
    url = reverse("user-list")
    response = api_client.post(url, {
        "email": "new@example.com",
        "full_name": "New User",
        "password": "securepass123",
        "password_confirm": "securepass123",
    })
    assert response.status_code == 201
    assert response.data["email"] == "new@example.com"


@pytest.mark.django_db
def test_get_me(auth_client, user):
    url = reverse("user-me")
    response = auth_client.get(url)
    assert response.status_code == 200
    assert response.data["email"] == user.email
```

## Common mistakes

| Mistake | Fix |
|---|---|
| `fields = "__all__"` in serializer | Always list explicit `fields = [...]` |
| Querying inside a loop (N+1) | Use `select_related` / `prefetch_related` |
| `settings.py` monolith with secrets | Split settings; load secrets from env via `django-environ` |
| Missing `AUTH_USER_MODEL` before first migration | Set `AUTH_USER_MODEL` before running any `makemigrations` |
| Direct `User` model import | Use `get_user_model()` or `settings.AUTH_USER_MODEL` in FK |
| `objects.get()` without `try/except` | Use `get_object_or_404()` or catch `DoesNotExist` |
| Hand-editing migration files | Only `makemigrations`; edit `operations` if unavoidable, test rollback |
| No `update_fields` on `.save()` | Always pass `update_fields=["field"]` for partial saves |
