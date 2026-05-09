#!/usr/bin/env bash
# Warns when console.* calls are found in a .ts/.tsx file after a write/edit.
# Ignores lines with eslint-disable comments.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Only run for TypeScript files
[[ "$FILE" == *.ts || "$FILE" == *.tsx ]] || exit 0

# Find console.* calls, ignoring eslint-disable lines
HITS=$(grep -n 'console\.' "$FILE" 2>/dev/null | grep -v '// *eslint-disable' | head -5)

if [ -n "$HITS" ]; then
  echo "⚠️  console.* found in $FILE (use pino logger instead):"
  echo "$HITS"
fi

exit 0
