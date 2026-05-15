#!/usr/bin/env bash
# Runs go vet on the package containing the just-saved Go file. Informational only.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.go) ;; *) exit 0 ;; esac

command -v go >/dev/null 2>&1 || exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
[ -f "$ROOT/go.mod" ] || exit 0

PKG_DIR=$(dirname "$FILE")
cd "$ROOT" || exit 0

OUTPUT=$(go vet "./$PKG_DIR/..." 2>&1 | head -20)
if [ -n "$OUTPUT" ]; then
  echo "🟡 go vet findings near $FILE:"
  echo "$OUTPUT"
fi

exit 0
