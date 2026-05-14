#!/usr/bin/env bash
# Runs tsc --noEmit after any .ts/.tsx file is written or edited.
# Exits silently if the file is not TypeScript or no tsconfig.json is found.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Only run for TypeScript files
[[ "$FILE" == *.ts || "$FILE" == *.tsx ]] || exit 0

# Find project root
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$CLAUDE_PLUGIN_ROOT")

# Only run if a tsconfig exists
[ -f "$ROOT/tsconfig.json" ] || exit 0

cd "$ROOT" || exit 0

OUTPUT=$(npx tsc --noEmit --pretty 2>&1 | grep -E 'error TS|^Found' | head -15)

if [ -n "$OUTPUT" ]; then
  echo "🔴 TypeScript errors in $FILE:"
  echo "$OUTPUT"
fi

exit 0
