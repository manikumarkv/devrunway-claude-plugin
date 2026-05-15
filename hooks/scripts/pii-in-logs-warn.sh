#!/usr/bin/env bash
# Flags log calls that include PII-named variables (email, password, ssn, etc.).
# Informational only — never blocks.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Skip plugin's own docs and test fixtures
case "$FILE" in
  */hooks/scripts/*|*/docs/HOOKS.md|*/layers/*) exit 0 ;;
esac

# Only inspect source files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.java|*.cs|*.php) ;;
  *) exit 0 ;;
esac

# PII-ish identifiers — token, ssn, password, email, phone, dob, credit_card, secret, api_key, auth, jwt
PII_VARS='password|passwd|pwd|secret|api[_-]?key|access[_-]?key|auth[_-]?token|bearer|jwt|ssn|credit[_-]?card|card[_-]?number|cvv|cvc|dob|date[_-]?of[_-]?birth'
LOG_CALLS='(log(ger)?|console)\.(info|debug|warn|error|trace|log|fatal)'

# Match log lines that reference any PII identifier on the same line
HIT=$(echo "$CONTENT" | grep -nEi "${LOG_CALLS}\(.*\b(${PII_VARS})\b.*\)" | head -5)

if [ -n "$HIT" ]; then
  echo "🟡 pii-in-logs-warn: log call references PII-named variable in $FILE — redact or drop the field:"
  echo "$HIT"
fi

exit 0
