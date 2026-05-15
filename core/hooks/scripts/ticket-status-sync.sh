#!/usr/bin/env bash
# On `git commit`, detects a ticket key in the commit message and prints a sync hint.
# Informational only — never blocks. Never touches external systems automatically;
# leaves the actual MCP/CLI call to the user or Claude (it has the context to do so).

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# Only inspect `git commit -m "..."` invocations
echo "$CMD" | grep -qE '\bgit[[:space:]]+commit\b' || exit 0
echo "$CMD" | grep -qE '(-m|--message)[[:space:]=]' || exit 0

MSG=$(echo "$CMD" | perl -ne '
  if (/(-m|--message)[\s=]+"((?:[^"\\]|\\.)*)"/) { print $2; exit }
  elsif (/(-m|--message)[\s=]+'\''((?:[^'\''\\]|\\.)*)'\''/) { print $2; exit }
  elsif (/(-m|--message)[\s=]+(\S+)/) { print $2; exit }
')

[ -z "$MSG" ] && exit 0

# Try several ticket-key shapes:
#   JIRA-style:  ABC-123, FOO-4
#   Linear-style (when prefixed): LIN-123 or ENG-45 (caught by JIRA shape)
#   GitHub-style: #123
KEYS=""
for k in $(echo "$MSG" | grep -oE '\b[A-Z][A-Z0-9]{1,9}-[0-9]+\b' | sort -u); do
  KEYS="$KEYS $k"
done
for k in $(echo "$MSG" | grep -oE '#[0-9]+' | sort -u); do
  KEYS="$KEYS $k"
done

# Trim
KEYS=$(echo "$KEYS" | xargs)
[ -z "$KEYS" ] && exit 0

echo "🔗 ticket-status-sync: detected ticket reference(s): $KEYS"
echo "   To move them to In Progress / Done, use the relevant MCP (mcp__jira__update_issue, mcp__linear__update_issue, mcp__gitlab__update_issue, mcp__git__update_issue) or the project's CLI."

exit 0
