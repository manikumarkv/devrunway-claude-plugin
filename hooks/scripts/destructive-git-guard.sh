#!/usr/bin/env bash
# Blocks destructive git/shell commands before they execute.
# Returns JSON to the Claude Code hook runtime.

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

BLOCKED_PATTERNS='git push.*--force|git reset --hard|git clean -f|rm -rf'

if echo "$CMD" | grep -qE "$BLOCKED_PATTERNS"; then
  echo '{"continue": false, "stopReason": "Destructive command blocked by plugin safety hook. Run manually if you are certain."}'
  exit 0
fi

echo '{"continue": true}'
exit 0
