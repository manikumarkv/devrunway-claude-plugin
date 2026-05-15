#!/usr/bin/env bash
# Runs ruff on the just-saved Python file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.py) ;; *) exit 0 ;; esac

command -v ruff >/dev/null 2>&1 || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 0

OUTPUT=$(ruff check --quiet "$FILE" 2>&1)
if [ -n "$OUTPUT" ]; then
  echo "🟡 ruff findings for $FILE:"
  echo "$OUTPUT" | head -30
fi

exit 0
