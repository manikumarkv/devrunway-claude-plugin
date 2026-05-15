#!/usr/bin/env bash
# Flags new TODO/FIXME/HACK comments that don't reference a ticket, suggesting to file one.
# Informational only — never blocks. Never creates issues automatically.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Skip the plugin's own docs (HOOKS.md describes these patterns and would self-trigger)
case "$FILE" in
  */docs/HOOKS.md|*/hooks/scripts/*|*/layers/*.md) exit 0 ;;
esac

# Only inspect source files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.java|*.cs|*.php|*.rs|*.swift|*.kt|*.scala) ;;
  *) exit 0 ;;
esac

# Match TODO|FIXME|HACK|XXX comments. A line is "OK" if it ALSO contains a ticket-like ref:
#   ABC-123 / FOO-4 (JIRA/Linear style)   OR   #123 (GitHub-style)
HITS=$(echo "$CONTENT" | grep -nE '(TODO|FIXME|HACK|XXX)' | grep -vE '[A-Z][A-Z0-9]+-[0-9]+|#[0-9]+' | head -5)

if [ -n "$HITS" ]; then
  echo "🟡 todo-to-issue: $FILE has TODO/FIXME comments without a ticket reference — consider filing an issue and updating the comment to TODO(TICKET-123):"
  echo "$HITS"
fi

exit 0
