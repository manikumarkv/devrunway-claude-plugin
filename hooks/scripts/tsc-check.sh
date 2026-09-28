#!/usr/bin/env bash
# Runs tsc --noEmit after any .ts/.tsx file is written or edited.
# Exits silently if the file is not TypeScript or no tsconfig.json is found.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Only run for TypeScript files
[[ "$FILE" == *.ts || "$FILE" == *.tsx ]] || exit 0

# Find the project root from the session's cwd, never the plugin checkout.
PROJECT=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
ROOT=$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT")

# Only run if a tsconfig exists
[ -f "$ROOT/tsconfig.json" ] || exit 0

cd "$ROOT" || exit 0

# --no-install: never download a package. Without a local typescript, plain
# `npx tsc` installs the unrelated squatted `tsc` package from npm.
# --pretty false: colour codes otherwise break the error grep.
OUTPUT=$(npx --no-install tsc --noEmit --pretty false 2>&1 | grep -E 'error TS|^Found' | head -15)

if [ -n "$OUTPUT" ]; then
  echo "🔴 TypeScript errors in $FILE:"
  echo "$OUTPUT"
fi

exit 0
