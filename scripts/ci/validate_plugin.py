#!/usr/bin/env python3
"""Static validation of the plugin tree. Run from the repo root.

Errors fail the build; warnings are printed as GitHub annotations only.
Checks:
  - manifests and hooks.json parse as JSON
  - every script referenced by hooks.json exists
  - every SKILL.md / agent .md / .eval.yaml passes skill-frontmatter-validate.sh
  - skill names are unique
  - `agent:` in a skill and `skills:` in an agent point at things that exist
  - backticked layers/, skills/, agents/, hooks/scripts/ paths in docs exist
  - every key /setup writes to stack.json exists in the schema, and vice versa for required keys
"""
import glob
import json
import os
import re
import subprocess
import sys

import yaml

errors = []
warnings = []


def err(path, msg):
    errors.append((path, msg))


def warn(path, msg):
    warnings.append((path, msg))


def frontmatter(path):
    text = open(path, encoding="utf-8").read()
    if not text.startswith("---"):
        return None
    try:
        d = yaml.safe_load(text.split("---")[1])
    except yaml.YAMLError:
        return None
    return d if isinstance(d, dict) else None


# 1. JSON manifests
for path in [".claude-plugin/plugin.json", ".claude-plugin/marketplace.json",
             "hooks/hooks.json", *glob.glob("setup/*.json")]:
    try:
        json.load(open(path, encoding="utf-8"))
    except FileNotFoundError:
        err(path, "file is missing")
    except json.JSONDecodeError as e:
        err(path, f"invalid JSON: {e}")

# 2. hooks.json script references
hooks_text = open("hooks/hooks.json", encoding="utf-8").read()
for ref in sorted(set(re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\s\"]+)", hooks_text))):
    if not os.path.isfile(ref):
        err("hooks/hooks.json", f"references missing script {ref}")

# 3. Frontmatter — reuse the hook so CI and edit-time checks never drift
targets = sorted(
    glob.glob("skills/**/SKILL.md", recursive=True)
    + glob.glob("layers/**/SKILL.md", recursive=True)
    + glob.glob("**/*.eval.yaml", recursive=True)
)
for path in targets:
    payload = json.dumps({"tool_input": {"file_path": path}})
    out = subprocess.run(["bash", "hooks/scripts/skill-frontmatter-validate.sh"],
                         input=payload, capture_output=True, text=True).stdout
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("❌"):
            err(path, line.lstrip("❌ ").split(": ", 1)[-1])
        elif line.startswith("⚠️"):
            warn(path, line.lstrip("⚠️ ").split(": ", 1)[-1])

# Agents use a different frontmatter shape; check the basics directly
agent_names = set()
for path in sorted(glob.glob("agents/*.md")):
    d = frontmatter(path)
    if d is None:
        err(path, "frontmatter missing or does not parse")
        continue
    for key in ("name", "description"):
        if not d.get(key):
            err(path, f"frontmatter is missing required `{key}:`")
    if d.get("name"):
        agent_names.add(d["name"])

# 4. Unique skill names + cross-references
skills = {}
for path in sorted(glob.glob("skills/**/SKILL.md", recursive=True)
                   + glob.glob("layers/**/SKILL.md", recursive=True)):
    d = frontmatter(path)
    if not d or not d.get("name"):
        continue  # already reported above
    name = d["name"]
    if name in skills:
        err(path, f"duplicate skill name `{name}` (also in {skills[name]})")
    else:
        skills[name] = path
    agent = d.get("agent")
    if agent and agent not in agent_names:
        err(path, f"`agent: {agent}` does not match any agents/*.md")

for path in sorted(glob.glob("agents/*.md")):
    d = frontmatter(path) or {}
    for s in d.get("skills") or []:
        if s not in skills:
            warn(path, f"`skills:` lists `{s}`, which is not a skill in this plugin")

# 5. Path references in docs, skills, agents and layers must exist.
# Backticked `layers/...`, `skills/...`, `agents/...`, `hooks/scripts/...` paths
# are instructions Claude follows; a missing one sends it looking for nothing.
REF = re.compile(r"`((?:layers|skills|agents|hooks/scripts)/[A-Za-z0-9_./-]+)`")
doc_files = (glob.glob("skills/**/*.md", recursive=True) + glob.glob("agents/*.md")
             + [f for f in glob.glob("layers/**/*.md", recursive=True) if not f.endswith("README.md")]
             + ["CLAUDE.md", "README.md", "CONTRIBUTING.md"])
for path in sorted(doc_files):
    for lineno, line in enumerate(open(path, encoding="utf-8"), 1):
        if "e.g." in line:  # illustrative paths ("e.g. `layers/analytics/`")
            continue
        for m in REF.finditer(line):
            ref = m.group(1).rstrip("/.")
            if "*" in ref or "<" in ref or os.path.exists(ref):
                continue
            err(f"{path}:{lineno}", f"references `{ref}`, which does not exist")

# 6. Every key /setup writes into stack.json exists in setup/stack.schema.json
# (which has additionalProperties: false, so an unknown key makes the file invalid).
setup_md = open("skills/setup/SKILL.md", encoding="utf-8").read()
m = re.search(r"## Output 1 — stack\.json.*?```json\n(.*?)```", setup_md, re.S)
schema = json.load(open("setup/stack.schema.json", encoding="utf-8"))
if not m:
    err("skills/setup/SKILL.md", "could not find the stack.json template under '## Output 1 — stack.json'")
else:
    template = m.group(1)
    props = schema.get("properties", {})
    top = re.findall(r'^  "([A-Za-z0-9_-]+)":', template, re.M)
    for key in top:
        if key not in props:
            err("setup/stack.schema.json", f"/setup writes `{key}` to stack.json but the schema has no such property")
    nested = re.findall(r'^    "([A-Za-z0-9_-]+)":', template, re.M)
    policy_props = props.get("policies", {}).get("properties", {})
    for key in nested:
        if key not in policy_props:
            err("setup/stack.schema.json", f"/setup writes `policies.{key}` but the schema has no such property")
    for key in schema.get("required", []):
        if key not in top:
            err("skills/setup/SKILL.md", f"schema requires `{key}` but the /setup stack.json template never writes it")

# Report
gha = os.environ.get("GITHUB_ACTIONS") == "true"
for level, items in (("warning", warnings), ("error", errors)):
    for path, msg in items:
        if gha:
            print(f"::{level} file={path}::{msg}")
        else:
            print(f"{level.upper()}: {path}: {msg}")

print(f"\nChecked {len(targets)} skill/eval files and {len(agent_names)} agents: "
      f"{len(errors)} error(s), {len(warnings)} warning(s).")
sys.exit(1 if errors else 0)
