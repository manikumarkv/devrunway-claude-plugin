#!/usr/bin/env bash
# Flags SELECT * in SQL files or in SQL strings inside source files. Informational only.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Skip plugin docs / fixtures
case "$FILE" in
  */hooks/scripts/*|*/docs/HOOKS.md|*/layers/*) exit 0 ;;
esac

# Only inspect SQL or backend source
case "$FILE" in
  *.sql|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.java|*.cs|*.php) ;;
  *) exit 0 ;;
esac

# Allow SELECT * inside common safe contexts: count(*), exists(select 1), CTE comments
HIT=$(echo "$CONTENT" | grep -niE 'SELECT[[:space:]]+\*' | grep -viE 'COUNT[[:space:]]*\(|EXPLAIN|--' | head -5)

if [ -n "$HIT" ]; then
  echo "🟡 no-select-star: SELECT * detected in $FILE — list the columns explicitly to avoid downstream breakage:"
  echo "$HIT"
fi

exit 0
