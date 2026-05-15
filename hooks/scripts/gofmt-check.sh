#!/usr/bin/env bash
# Runs gofmt -l on the just-saved Go file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.go) ;; *) exit 0 ;; esac

command -v gofmt >/dev/null 2>&1 || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 0

OUTPUT=$(gofmt -l "$FILE" 2>&1)
if [ -n "$OUTPUT" ]; then
  echo "🟡 gofmt: $FILE is not formatted — run: gofmt -w \"$FILE\""
fi

exit 0
