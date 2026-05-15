#!/usr/bin/env bash
# Runs markdownlint on the just-saved Markdown file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.md|*.mdx|*.markdown) ;; *) exit 0 ;; esac

# Try the standalone CLI first, then the Node package via npx
RUNNER=""
if command -v markdownlint >/dev/null 2>&1; then
  RUNNER="markdownlint"
elif command -v markdownlint-cli2 >/dev/null 2>&1; then
  RUNNER="markdownlint-cli2"
elif command -v npx >/dev/null 2>&1; then
  RUNNER="npx --no-install markdownlint-cli"
else
  exit 0
fi

OUTPUT=$($RUNNER "$FILE" 2>&1 | head -20)

# If npx fell through because the package isn't installed locally, treat as no-op
if echo "$OUTPUT" | grep -qE 'npx canceled|missing packages|npm error'; then
  exit 0
fi

if [ -n "$OUTPUT" ]; then
  echo "🟡 markdownlint findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
