#!/usr/bin/env bash
# Runs black --check on the just-saved Python file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.py) ;; *) exit 0 ;; esac

command -v black >/dev/null 2>&1 || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 0

OUTPUT=$(black --check --quiet "$FILE" 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo "🟡 black formatting issue in $FILE — run: black \"$FILE\""
fi

exit 0
