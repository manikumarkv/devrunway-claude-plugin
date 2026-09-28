#!/usr/bin/env python3
"""PostToolUse hook: auto-load layer standards for the file Claude just touched.

Claude Code only registers skills/<name>/SKILL.md, so the layers under layers/
are never loaded as skills. This hook is what makes their `paths:` globs work:
on Read/Edit/Write/MultiEdit it matches the file against layers/index.json and
hands Claude the matching layers' short SKILL.md summaries as additionalContext,
with the path of the full detail file for when it needs specifics.

- Each layer is injected at most once per session.
- At most MAX_LAYERS per tool call; specific globs outrank extension-only ones.
- Layers that contradict the project's stack are skipped (the Vue layer in a
  React project). The stack comes from stack.json (written by /setup) and,
  for slots it does not cover, from package.json dependencies.
- Standard library only; any failure exits 0 silently. Never blocks.
"""
import json
import os
import re
import sys
import tempfile

MAX_LAYERS = 3
MAX_SUMMARY_CHARS = 4000
PLUGIN_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INDEX = os.path.join(PLUGIN_ROOT, "layers", "index.json")
CATCHALL = re.compile(r"^(?:\*\*/)?\*(?:\.[A-Za-z0-9]+)?$")


def glob_to_regex(pattern):
    """Translate a paths: glob to a regex over a /-separated relative path."""
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        elif pattern[i] == "{":
            end = pattern.find("}", i)
            if end == -1:
                out.append(re.escape("{"))
                i += 1
            else:
                alts = pattern[i + 1:end].split(",")
                out.append("(?:" + "|".join(re.escape(a) for a in alts) + ")")
                i = end + 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def specificity(pattern):
    """Higher = more specific. Extension-only catch-alls rank last."""
    if CATCHALL.match(pattern):
        return 0
    return len(re.sub(r"[*?{},]", "", pattern)) + 10


# npm packages that identify a tech, per stack.json slot. Used only when
# stack.json does not answer the slot: in a project with a package.json, a
# layer for an npm-identifiable tech loads only if one of its packages is a
# dependency (no zod layer without zod, no Vue layer in a React app).
NPM_SIGNALS = {
    "frontend": {"react": ["react"], "vue": ["vue"], "angular": ["@angular/core"], "nextjs": ["next"]},
    "ui-components": {"shadcn": ["@radix-ui/react-slot", "class-variance-authority"], "mui": ["@mui/material"],
                      "ant-design": ["antd"], "chakra": ["@chakra-ui/react"]},
    "state": {"zustand": ["zustand"], "redux-toolkit": ["@reduxjs/toolkit"], "jotai": ["jotai"], "pinia": ["pinia"]},
    "validation": {"zod": ["zod"], "yup": ["yup"], "joi": ["joi"], "valibot": ["valibot"]},
    "testing-unit": {"vitest": ["vitest"], "jest": ["jest"]},
    "logging-framework": {"pino": ["pino"], "winston": ["winston"]},
    "css": {"tailwind": ["tailwindcss"], "styled-components": ["styled-components"]},
    "database": {"postgres-prisma": ["@prisma/client", "prisma"], "neon": ["@neondatabase/serverless"],
                 "mongodb": ["mongodb", "mongoose"], "dynamodb": ["@aws-sdk/client-dynamodb", "@aws-sdk/lib-dynamodb", "dynamoose"]},
}


def slot_and_tech(layer_stack):
    parts = (layer_stack or "").split("/")
    if len(parts) < 2:
        return None, None
    return "-".join(parts[:-1]), parts[-1]


def stack_allows(layer_stack, stack_json, npm_deps):
    """False only when the project clearly picked a different tech for this slot."""
    slot, tech = slot_and_tech(layer_stack)
    if not slot:
        return True
    if stack_json and slot in stack_json:
        chosen = stack_json[slot]
        chosen = chosen if isinstance(chosen, list) else [chosen]
        return tech in [str(c) for c in chosen]
    signals = NPM_SIGNALS.get(slot, {})
    if npm_deps is not None and tech in signals:
        return any(p in npm_deps for p in signals[tech])
    return True


NON_NODE_MANIFESTS = ("pyproject.toml", "requirements.txt", "setup.py", "Pipfile", "go.mod",
                      "Cargo.toml", "pubspec.yaml", "Gemfile", "pom.xml", "build.gradle", "composer.json")


def load_npm_deps(project):
    """Dependencies from package.json. None when there is no package.json;
    an empty set when there is none but the project is clearly another
    language (so npm-only layers such as nextjs stay out of a Django app)."""
    try:
        with open(os.path.join(project, "package.json"), encoding="utf-8") as f:
            pkg = json.load(f)
    except (OSError, ValueError):
        if any(os.path.exists(os.path.join(project, m)) for m in NON_NODE_MANIFESTS):
            return set()
        return None
    deps = set()
    for key in ("dependencies", "devDependencies", "peerDependencies"):
        if isinstance(pkg.get(key), dict):
            deps.update(pkg[key])
    return deps


def load_stack_json(project):
    path = os.path.join(project, "stack.json")
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) else None
    except (OSError, ValueError):
        return None


def summary(layer_dir):
    """The SKILL.md body (everything after the frontmatter), capped."""
    with open(os.path.join(PLUGIN_ROOT, layer_dir, "SKILL.md"), encoding="utf-8") as f:
        text = f.read()
    parts = text.split("---", 2)
    body = (parts[2] if len(parts) == 3 else text).strip()
    if len(body) > MAX_SUMMARY_CHARS:
        body = body[:MAX_SUMMARY_CHARS].rsplit("\n", 1)[0] + "\n…(summary truncated; see the full standards file)"
    return body


def seen_file(session_id):
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", session_id or "no-session")
    d = os.path.join(tempfile.gettempdir(), "devrunway-layers")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, safe)


def main():
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path") or tool_input.get("path") or tool_input.get("notebook_path")
    if not file_path:
        return
    project = payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    abs_file = os.path.abspath(os.path.join(project, file_path))
    rel = os.path.relpath(abs_file, project).replace(os.sep, "/")
    if rel.startswith("../"):
        return  # outside the project

    with open(INDEX, encoding="utf-8") as f:
        layers = json.load(f)["layers"]
    stack_json = load_stack_json(project)
    npm_deps = load_npm_deps(project)

    matches = []
    for layer in layers:
        best = max((specificity(p) for p in layer["paths"] if glob_to_regex(p).match(rel)), default=None)
        if best is not None and stack_allows(layer.get("stack"), stack_json, npm_deps):
            matches.append((best, layer))
    if not matches:
        return

    state = seen_file(payload.get("session_id"))
    try:
        with open(state, encoding="utf-8") as f:
            seen = set(f.read().split())
    except OSError:
        seen = set()

    matches.sort(key=lambda m: -m[0])
    fresh = [layer for _, layer in matches if layer["dir"] not in seen][:MAX_LAYERS]
    if not fresh:
        return

    sections = []
    for layer in fresh:
        detail = os.path.join(PLUGIN_ROOT, layer["detail"]) if layer.get("detail") else None
        pointer = (f"\n\nFull standards: {detail}. Read it before non-trivial changes this layer governs."
                   if detail else "")
        sections.append(f"### {layer['name']} ({layer.get('stack') or layer['dir']})\n\n{summary(layer['dir'])}{pointer}")

    context = (f"devrunway: team standards that apply to `{rel}` (auto-loaded once per session). "
               f"Follow them for this and similar files.\n\n" + "\n\n---\n\n".join(sections))

    with open(state, "a", encoding="utf-8") as f:
        f.write("".join(layer["dir"] + "\n" for layer in fresh))

    json.dump({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": context}}, sys.stdout)


if __name__ == "__main__":
    try:
        main()
    except Exception:  # never break the user's session over a standards hint
        pass
    sys.exit(0)
