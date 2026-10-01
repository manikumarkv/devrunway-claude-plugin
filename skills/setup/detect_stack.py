#!/usr/bin/env python3
"""Detect a project's stack for /setup, so it asks only what files can't answer.

    python3 detect_stack.py [project-dir]

Prints JSON: {"detected": {slot: value}, "evidence": {slot: "why"}, "ask": [slots]}.
Every value is valid for setup/stack.schema.json; slots it can't see are left
out (the layer-autoload hook then falls back to package.json for them).
Standard library only.
"""
import json
import os
import re
import subprocess
import sys

# slot -> [(value, [npm packages or package prefixes ending in "/"])], first match wins
NPM = {
    "ui-components": [("shadcn", ["@radix-ui/react-slot", "class-variance-authority"]), ("mui", ["@mui/material"]),
                      ("ant-design", ["antd"]), ("chakra", ["@chakra-ui/react"])],
    "css": [("tailwind", ["tailwindcss"]), ("styled-components", ["styled-components"]), ("bootstrap", ["bootstrap"])],
    "state": [("zustand", ["zustand"]), ("redux-toolkit", ["@reduxjs/toolkit"]), ("jotai", ["jotai"]), ("pinia", ["pinia"])],
    "i18n": [("react-i18next", ["react-i18next"]), ("lingui", ["@lingui/core", "@lingui/react"]), ("vue-i18n", ["vue-i18n"])],
    "component-docs": [("storybook", ["storybook", "@storybook/"]), ("ladle", ["@ladle/react"])],
    "backend": [("node-express", ["express"])],
    "api-style": [("trpc", ["@trpc/server"]), ("graphql", ["graphql", "@apollo/server"]), ("grpc", ["@grpc/grpc-js"])],
    "validation": [("zod", ["zod"]), ("yup", ["yup"]), ("valibot", ["valibot"]), ("joi", ["joi"])],
    "api-docs": [("swagger-express", ["swagger-ui-express", "swagger-jsdoc"])],
    "cloud": [("aws", ["aws-cdk-lib", "@aws-sdk/", "aws-sdk"]), ("gcp", ["@google-cloud/"]), ("azure", ["@azure/"])],
    "database": [("neon", ["@neondatabase/serverless"]), ("postgres-prisma", ["@prisma/client", "prisma"]),
                 ("mongodb", ["mongodb", "mongoose"]),
                 ("dynamodb", ["@aws-sdk/client-dynamodb", "@aws-sdk/lib-dynamodb", "dynamoose"])],
    "auth": [("clerk", ["@clerk/"]), ("cognito", ["aws-amplify", "amazon-cognito-identity-js", "@aws-sdk/client-cognito-identity-provider"]),
             ("auth0", ["@auth0/"]), ("azure-ad", ["@azure/msal-browser", "@azure/msal-react", "@azure/msal-node"]),
             ("firebase", ["firebase", "firebase-admin"])],
    "cache-queue": [("bullmq", ["bullmq"]), ("redis", ["ioredis", "redis"]), ("sqs", ["@aws-sdk/client-sqs"]),
                    ("rabbitmq", ["amqplib"])],
    "storage": [("uploadthing", ["uploadthing"]), ("cloudinary", ["cloudinary"]), ("s3", ["@aws-sdk/client-s3"]),
                ("gcs", ["@google-cloud/storage"])],
    "secrets": [("aws-secrets-manager", ["@aws-sdk/client-secrets-manager"]), ("vault", ["node-vault"])],
    "feature-flags": [("launchdarkly", ["launchdarkly-", "@launchdarkly/"]), ("flagsmith", ["flagsmith"]),
                      ("aws-appconfig", ["@aws-sdk/client-appconfig", "@aws-sdk/client-appconfigdata"])],
    "logging-framework": [("pino", ["pino"]), ("winston", ["winston"]), ("morgan", ["morgan"])],
    "error-monitoring": [("sentry", ["@sentry/"]), ("datadog-apm", ["dd-trace"]), ("bugsnag", ["@bugsnag/"])],
    "realtime": [("socketio", ["socket.io", "socket.io-client"]), ("pusher", ["pusher", "pusher-js"]), ("ably", ["ably"])],
    "search": [("pagefind", ["pagefind", "astro-pagefind", "@pagefind/"]), ("algolia", ["algoliasearch"]),
               ("typesense", ["typesense"]), ("elasticsearch", ["@elastic/elasticsearch"])],
    "payment": [("stripe", ["stripe", "@stripe/"]), ("paypal", ["@paypal/"]), ("braintree", ["braintree"])],
    "email": [("resend", ["resend"]), ("sendgrid", ["@sendgrid/mail"]), ("ses", ["@aws-sdk/client-ses", "@aws-sdk/client-sesv2"])],
    "analytics": [("posthog", ["posthog-js", "posthog-node"])],
    "cms": [("keystatic", ["@keystatic/"])],
    "testing-unit": [("vitest", ["vitest"]), ("jest", ["jest"])],
    "testing-e2e": [("playwright", ["@playwright/test", "playwright"]), ("cypress", ["cypress"]),
                    ("selenium", ["selenium-webdriver"]), ("webdriverio", ["webdriverio", "@wdio/"])],
    "mocking": [("msw", ["msw"]), ("mirage", ["miragejs"]), ("json-server", ["json-server"])],
}
# Frontend can hold several (Astro + React islands, Next.js + React).
FRONTEND = [("nextjs", ["next"]), ("astro", ["astro"]), ("react", ["react"]), ("vue", ["vue"]), ("angular", ["@angular/core"])]
# Python packages, matched as words in pyproject.toml / requirements*.txt / Pipfile
PYTHON = {
    "backend": [("python-fastapi", ["fastapi"]), ("python-django", ["django"])],
    "api-docs": [("openapi-fastapi", ["fastapi"])],
    "database": [("sqlalchemy", ["sqlalchemy"])],
    "testing-unit": [("pytest", ["pytest"])],
}
# Slots no file can reveal: always asked.
ALWAYS_ASK = ["project-management", "documents", "design", "policies"]


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def exists(root, *names):
    return any(os.path.exists(os.path.join(root, n)) for n in names)


def has_pkg(deps, names):
    for n in names:
        if n.endswith("/") or n.endswith("-"):
            hit = next((d for d in deps if d.startswith(n)), None)
            if hit:
                return hit
        elif n in deps:
            return n
    return None


def find_files(root, pattern, max_depth=3):
    rx = re.compile(pattern)
    skip = {"node_modules", ".git", "dist", "build", ".next", ".venv", "venv", "__pycache__"}
    for dirpath, dirnames, filenames in os.walk(root):
        depth = dirpath[len(root):].count(os.sep)
        dirnames[:] = [d for d in dirnames if d not in skip and depth < max_depth]
        for f in filenames:
            if rx.search(f):
                return os.path.relpath(os.path.join(dirpath, f), root)
    return None


def detect(root):
    found, why = {}, {}

    def put(slot, value, reason):
        if slot not in found:
            found[slot] = value
            why[slot] = reason

    # npm
    pkg = {}
    try:
        pkg = json.loads(read(os.path.join(root, "package.json")) or "{}")
    except ValueError:
        pass
    deps = set()
    for key in ("dependencies", "devDependencies", "peerDependencies"):
        if isinstance(pkg.get(key), dict):
            deps.update(pkg[key])
    fronts = [v for v, names in FRONTEND if has_pkg(deps, names)]
    if fronts:
        found["frontend"] = fronts[0] if len(fronts) == 1 else fronts
        why["frontend"] = "package.json: " + ", ".join(fronts)
    for slot, rules in NPM.items():
        for value, names in rules:
            hit = has_pkg(deps, names)
            if hit:
                put(slot, value, f"package.json: {hit}")
                break

    # Python
    py = " ".join(read(os.path.join(root, f)).lower() for f in ("pyproject.toml", "requirements.txt", "requirements-dev.txt", "Pipfile"))
    for slot, rules in PYTHON.items():
        for value, names in rules:
            if any(re.search(rf"(?<![\w-]){re.escape(n)}(?![\w-])", py) for n in names):
                put(slot, value, f"python manifest: {names[0]}")
                break

    # Files and folders
    if exists(root, "components.json"):
        found["ui-components"], why["ui-components"] = "shadcn", "components.json"
    if "css" not in found and find_files(root, r"\.module\.(css|scss)$"):
        put("css", "css-modules", "*.module.css files")
    if exists(root, ".storybook"):
        put("component-docs", "storybook", ".storybook/")
    if find_files(root, r"\.csproj$"):
        put("backend", "dotnet", "*.csproj")
    if exists(root, "pnpm-lock.yaml"):
        put("package-manager", "pnpm", "pnpm-lock.yaml")
    elif exists(root, "bun.lockb", "bun.lock"):
        put("package-manager", "bun", "bun.lock")
    elif exists(root, "yarn.lock"):
        put("package-manager", "yarn", "yarn.lock")
    elif exists(root, "package-lock.json"):
        put("package-manager", "npm", "package-lock.json")
    if os.path.isdir(os.path.join(root, ".github", "workflows")):
        put("ci", "github-actions", ".github/workflows/")
    elif exists(root, ".gitlab-ci.yml"):
        put("ci", "gitlab-ci", ".gitlab-ci.yml")
    elif exists(root, ".circleci/config.yml"):
        put("ci", "circleci", ".circleci/config.yml")
    elif exists(root, "azure-pipelines.yml"):
        put("ci", "azure-pipelines", "azure-pipelines.yml")
    if exists(root, "sonar-project.properties"):
        put("code-quality", "sonarqube", "sonar-project.properties")
    elif exists(root, ".snyk"):
        put("code-quality", "snyk", ".snyk")
    elif exists(root, ".github/dependabot.yml", ".github/dependabot.yaml"):
        put("code-quality", "github-security", ".github/dependabot.yml")
    if exists(root, "serverless.yml", "serverless.ts"):
        put("container", "serverless", "serverless.yml")
    elif exists(root, "vercel.json"):
        put("container", "vercel", "vercel.json")
    elif exists(root, "railway.json", "railway.toml"):
        put("container", "railway", "railway.json")
    elif exists(root, "Chart.yaml", "k8s", "kubernetes", "helm"):
        put("container", "kubernetes", "Kubernetes manifests")
    elif exists(root, "Dockerfile", "docker-compose.yml", "compose.yaml"):
        put("container", "docker", "Dockerfile")
    if exists(root, "cdk.json", "serverless.yml"):
        put("cloud", "aws", "cdk.json / serverless.yml")
    if exists(root, "doppler.yaml"):
        put("secrets", "doppler", "doppler.yaml")
    if exists(root, "bruno.json") or find_files(root, r"\.bru$"):
        put("testing-api", "bruno", "Bruno collection")
    elif find_files(root, r"\.postman_collection\.json$"):
        put("testing-api", "postman", "Postman collection")
    pubspec = read(os.path.join(root, "pubspec.yaml"))
    if re.search(r"^\s*flutter\s*:", pubspec, re.M):
        put("mobile", "flutter", "pubspec.yaml: flutter")
    if "firebase_messaging" in pubspec:
        put("notifications", "fcm", "pubspec.yaml: firebase_messaging")
    if exists(root, "tsconfig.json"):
        put("language", "typescript", "tsconfig.json")
    elif py.strip():
        put("language", "python", "python manifest")

    # Git host
    try:
        remote = subprocess.run(["git", "-C", root, "remote", "get-url", "origin"],
                                capture_output=True, text=True, timeout=5).stdout.lower()
    except (OSError, subprocess.SubprocessError):
        remote = ""
    for host, value in (("github.com", "github"), ("gitlab", "gitlab"), ("bitbucket.org", "bitbucket"),
                        ("dev.azure.com", "azure-devops"), ("visualstudio.com", "azure-devops")):
        if host in remote:
            put("source-control", value, f"git remote: {host}")
            break
    return found, why


def schema_filter(found, why):
    """Drop anything setup/stack.schema.json would reject."""
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        with open(os.path.join(here, "..", "..", "setup", "stack.schema.json"), encoding="utf-8") as f:
            props = json.load(f)["properties"]
    except (OSError, ValueError, KeyError):
        return found, why

    def allowed(slot):
        spec = props.get(slot, {})
        if "enum" in spec:
            return set(spec["enum"])
        for alt in spec.get("oneOf", []):
            if "enum" in alt:
                return set(alt["enum"])
        return set()

    out, reasons = {}, {}
    for slot, value in found.items():
        ok = allowed(slot)
        values = value if isinstance(value, list) else [value]
        values = [v for v in values if v in ok]
        if values:
            out[slot] = values if isinstance(value, list) and len(values) > 1 else values[0]
            reasons[slot] = why[slot]
    return out, reasons


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.getcwd())
    found, why = schema_filter(*detect(root))
    ask = [s for s in ALWAYS_ASK if s not in found]
    if "source-control" not in found:
        ask.insert(0, "source-control")
    print(json.dumps({"detected": found, "evidence": why, "ask": ask}, indent=2))


if __name__ == "__main__":
    main()
