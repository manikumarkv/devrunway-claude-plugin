#!/usr/bin/env bash
# Validates SKILL.md / .eval.yaml frontmatter after a write or edit.
#
# Exists because a 2026-05-14 bulk restructure inserted a `stack:` line without
# a trailing newline in 11 of 41 files, gluing it to the following key
# (`stack: cloud/awspaths:`). That made the whole frontmatter unparseable — not
# just `paths:` but `name` and `description` too — and it went unnoticed for
# months because nothing validates frontmatter. A layer whose frontmatter does
# not parse is invisible to stack-dispatcher and loads for no one.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -n "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  *SKILL.md|*.eval.yaml) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$FILE" <<'PY'
import sys, io, re

path = sys.argv[1]
try:
    import yaml
except ImportError:
    sys.exit(0)

text = io.open(path, encoding='utf-8').read()

if path.endswith('.eval.yaml'):
    try:
        d = yaml.safe_load(text)
    except Exception as e:
        print(f"❌ {path}: unparseable YAML\n   {str(e).splitlines()[0]}")
        sys.exit(0)
    if isinstance(d, dict):
        import os, glob
        missing = [p for p in (d.get('skill_files') or []) if not os.path.exists(p)]
        if missing:
            print(f"❌ {path}: skill_files references missing file(s): {', '.join(missing)}")
        skill_mds = [p for p in (d.get('skill_files') or []) if p.endswith('SKILL.md')]
        details = [p for p in (d.get('skill_files') or []) if p.endswith('.md') and not p.endswith('SKILL.md')]
        if skill_mds and not details:
            for sm in skill_mds:
                sibs = [f for f in glob.glob(os.path.dirname(sm) + '/*.md')
                        if os.path.basename(f) not in ('SKILL.md', 'README.md')]
                if sibs:
                    print(f"⚠️  {path}: skill_files lists only SKILL.md, but layer-consultant "
                          f"loads the detail file at runtime. Add: {', '.join(sibs)}")
                    break
    sys.exit(0)

# SKILL.md
if not text.startswith('---'):
    print(f"❌ {path}: no frontmatter block (must start with ---)")
    sys.exit(0)
if text.count('\n---') < 1:
    print(f"❌ {path}: frontmatter is not closed (missing the second ---)")
    sys.exit(0)

fm = text.split('---')[1]

# the exact 2026-05-14 defect: a value that swallowed the next key
glue = re.search(r'^([a-z-]+): \S*?(paths|allowed-tools|user-invocable|effort|context|mcp|argument-hint|arguments|model|agent):',
                 fm, re.M)
if glue:
    print(f"❌ {path}: line {glue.group(0)!r} has two keys glued together — "
          f"missing newline after the `{glue.group(1)}:` value. The whole frontmatter "
          f"fails to parse, which makes this layer invisible to stack-dispatcher.")
    sys.exit(0)

try:
    d = yaml.safe_load(fm)
except Exception as e:
    print(f"❌ {path}: frontmatter does not parse\n   {str(e).splitlines()[0]}")
    sys.exit(0)

if not isinstance(d, dict):
    print(f"❌ {path}: frontmatter is not a mapping")
    sys.exit(0)

for key in ('name', 'description'):
    if not d.get(key):
        print(f"❌ {path}: frontmatter is missing required `{key}:`")

if '/layers/' in path.replace('\\', '/') or path.startswith('layers/'):
    if 'paths' not in d and d.get('user-invocable') is not True:
        print(f"⚠️  {path}: background layer has no `paths:` — stack-dispatcher "
              f"cannot route it, so it will never load. Add globs, or set user-invocable: true.")

    # Catch-all globs: a pattern constrained only by file extension, anywhere in
    # the tree. stack-dispatcher takes at most 5 layers per dispatch, so these
    # crowd out the layer the file was actually about. See ADR 0001 and the
    # "Glob scope" rule in CONTRIBUTING.md. Warn only — a language or format
    # layer (typescript-patterns on **/*.ts, sketch on **/*.sketch) is a
    # legitimate exception, and this script cannot tell which is which.
    catchall_re = re.compile(r'^(?:\*\*/)?\*(?:\.[A-Za-z0-9]+)?$')
    paths = d.get('paths')
    if isinstance(paths, list):
        offenders = [str(x) for x in paths if catchall_re.match(str(x))]
        if offenders:
            print(f"⚠️  {path}: catch-all glob(s) {', '.join(offenders)} — constrained only "
                  f"by extension, so they match that file type anywhere in any project. This "
                  f"layer then competes for one of stack-dispatcher's 5 slots on every such "
                  f"file and displaces more specific layers. Scope by "
                  f"directory or filename instead. Ignore this only if the layer's subject "
                  f"IS that file format. Do not over-narrow: a layer that matches nothing "
                  f"never loads and nothing reports it.")
PY

exit 0
