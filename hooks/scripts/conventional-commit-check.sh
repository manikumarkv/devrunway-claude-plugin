#!/usr/bin/env bash
# Validates `git commit -m "..."` messages follow the Conventional Commits format.
# Blocks on violation. Only inspects -m / --message forms; lets editor-driven commits pass.

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# Only target git commit with an inline message
echo "$CMD" | grep -qE '\bgit[[:space:]]+commit\b' || { echo '{"continue": true}'; exit 0; }
echo "$CMD" | grep -qE '(-m|--message)[[:space:]=]' || { echo '{"continue": true}'; exit 0; }

# Extract the first quoted argument after -m / --message
MSG=$(echo "$CMD" | perl -ne '
  if (/(-m|--message)[\s=]+"((?:[^"\\]|\\.)*)"/) { print $2; exit }
  elsif (/(-m|--message)[\s=]+'\''((?:[^'\''\\]|\\.)*)'\''/) { print $2; exit }
  elsif (/(-m|--message)[\s=]+(\S+)/) { print $2; exit }
')

[ -z "$MSG" ] && { echo '{"continue": true}'; exit 0; }

# Take only the subject line
SUBJECT=$(echo "$MSG" | head -1)

# Validate format: type(scope)?: subject
TYPES='feat|fix|chore|docs|test|refactor|perf|style|build|ci|revert'
if ! echo "$SUBJECT" | grep -qE "^($TYPES)(\([a-z0-9._/-]+\))?!?: .+"; then
  STOP="conventional-commit-check: message must follow 'type(scope): subject'. Allowed types: $TYPES. Example: 'feat(auth): add password reset'. Got: '$SUBJECT'"
  echo "{\"continue\": false, \"stopReason\": \"$STOP\"}"
  exit 0
fi

# Subject length
LEN=${#SUBJECT}
if [ "$LEN" -gt 72 ]; then
  echo "{\"continue\": false, \"stopReason\": \"conventional-commit-check: subject line is $LEN chars; keep it ≤72.\"}"
  exit 0
fi

echo '{"continue": true}'
exit 0
