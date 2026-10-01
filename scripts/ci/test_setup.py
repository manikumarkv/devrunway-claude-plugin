#!/usr/bin/env python3
"""Tests for /setup: the stack detector and the stack.json it leads to.

Run from the repo root: python3 scripts/ci/test_setup.py
- detect_stack.py finds the right slots in fixture projects and asks only what it can't see
- every detector result, and the example in skills/setup/SKILL.md, validates against the schema
- the reference table in skills/setup/SKILL.md lists exactly the schema's values
"""
import json
import os
import re
import subprocess
import sys
import tempfile

import jsonschema

ROOT = os.getcwd()
DETECT = os.path.join(ROOT, "skills", "setup", "detect_stack.py")
SCHEMA = json.load(open(os.path.join(ROOT, "setup", "stack.schema.json"), encoding="utf-8"))
SETUP_MD = open(os.path.join(ROOT, "skills", "setup", "SKILL.md"), encoding="utf-8").read()
validator = jsonschema.Draft7Validator(SCHEMA)
failures = []


def check(cond, msg):
    print(("ok    " if cond else "FAIL  ") + msg)
    if not cond:
        failures.append(msg)


def project(files):
    d = tempfile.mkdtemp(prefix="setup-fixture-")
    for path, content in files.items():
        full = os.path.join(d, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8") as f:
            f.write(content if isinstance(content, str) else json.dumps(content))
    return d


def detect(d):
    out = subprocess.run([sys.executable, DETECT, d], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def stack_json(result, answers=None):
    doc = {"devrunway": "1.0", **result["detected"], **(answers or {})}
    doc["policies"] = {"protect-main": False, "conventional-commits": False}
    return doc


# 1. Typical Next.js app
r = detect(project({
    "package.json": {"dependencies": {"next": "15", "react": "19", "zod": "3", "@prisma/client": "5",
                                      "@clerk/nextjs": "6", "tailwindcss": "4"},
                     "devDependencies": {"vitest": "2", "@playwright/test": "1"}},
    "pnpm-lock.yaml": "", "tsconfig.json": "{}", "components.json": "{}",
    ".github/workflows/ci.yml": "on: push",
}))
d = r["detected"]
check(d.get("frontend") == ["nextjs", "react"], "Next.js app: frontend is [nextjs, react]")
for slot, value in [("validation", "zod"), ("database", "postgres-prisma"), ("auth", "clerk"), ("css", "tailwind"),
                    ("ui-components", "shadcn"), ("testing-unit", "vitest"), ("testing-e2e", "playwright"),
                    ("package-manager", "pnpm"), ("ci", "github-actions"), ("language", "typescript")]:
    check(d.get(slot) == value, f"Next.js app: {slot} = {value}")
check(len(r["ask"]) <= 5, f"Next.js app: asks {len(r['ask'])} question(s), at most 5")
check(not list(validator.iter_errors(stack_json(r, {"source-control": "github", "project-management": "linear"}))),
      "Next.js app: resulting stack.json validates")

# 2. Astro site with React islands
r = detect(project({"package.json": {"dependencies": {"astro": "5", "react": "19", "@keystatic/core": "0.5",
                                                      "posthog-js": "1"}, "devDependencies": {"pagefind": "1"}}}))
d = r["detected"]
check(d.get("frontend") == ["astro", "react"], "Astro site: frontend is [astro, react]")
check(d.get("cms") == "keystatic" and d.get("analytics") == "posthog" and d.get("search") == "pagefind",
      "Astro site: cms, analytics and search detected")

# 3. Django API
r = detect(project({"requirements.txt": "Django==5.0\npytest==8\n", "Dockerfile": "FROM python"}))
d = r["detected"]
check(d.get("backend") == "python-django" and d.get("testing-unit") == "pytest", "Django: backend and pytest detected")
check(d.get("language") == "python" and d.get("container") == "docker", "Django: language and container detected")
check("frontend" not in d, "Django: no frontend guessed")

# 4. Flutter app
r = detect(project({"pubspec.yaml": "name: app\ndependencies:\n  flutter:\n    sdk: flutter\n  firebase_messaging: ^15.0.0\n"}))
check(r["detected"].get("mobile") == "flutter" and r["detected"].get("notifications") == "fcm",
      "Flutter: mobile and notifications detected")
check(not list(validator.iter_errors(stack_json(r))), "Flutter: resulting stack.json validates")

# 5. Empty folder: nothing guessed, source control asked
r = detect(project({"README.md": "hi"}))
check(r["detected"] == {}, "empty folder: nothing detected")
check(r["ask"][0] == "source-control", "empty folder: asks where the code lives")

# 6. The example in SKILL.md validates
m = re.search(r"### Output 1 — stack\.json.*?```json\n(.*?)```", SETUP_MD, re.S)
example = json.loads(m.group(1)) if m else None
check(example is not None and not list(validator.iter_errors(example)), "SKILL.md stack.json example validates")

# 7. The reference table matches the schema
table = dict(re.findall(r"^\| `([a-z0-9-]+)` \| (`.*?) \|$", SETUP_MD.split("## Reference — slots and values", 1)[-1], re.M))
for slot, spec in SCHEMA["properties"].items():
    if slot in ("devrunway", "policies"):
        continue
    enum = spec.get("enum") or spec["oneOf"][0]["enum"]
    want = [v for v in enum if v != "none"]
    got = re.findall(r"`([^`]+)`", table.get(slot, ""))
    check(got == want, f"reference table lists the schema values for {slot}")

print(f"\n{len(failures)} failure(s)")
sys.exit(1 if failures else 0)
