#!/usr/bin/env bash
# Runs mypy on the just-saved Python file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.py) ;; *) exit 0 ;; esac

command -v mypy >/dev/null 2>&1 || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Need a mypy config or pyproject.toml with [tool.mypy] to behave well
HAS_CONFIG=0
for c in mypy.ini .mypy.ini pyproject.toml setup.cfg; do
  if [ -f "$ROOT/$c" ]; then
    if [ "$c" = "pyproject.toml" ] && ! grep -q "^\[tool\.mypy\]" "$ROOT/$c" 2>/dev/null; then continue; fi
    if [ "$c" = "setup.cfg" ] && ! grep -q "^\[mypy\]" "$ROOT/$c" 2>/dev/null; then continue; fi
    HAS_CONFIG=1; break
  fi
done
[ "$HAS_CONFIG" = "0" ] && exit 0

cd "$ROOT" || exit 0

OUTPUT=$(mypy --no-error-summary --hide-error-context "$FILE" 2>&1 | head -20)
if echo "$OUTPUT" | grep -q "error:"; then
  echo "🟡 mypy findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
