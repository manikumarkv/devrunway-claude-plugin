#!/usr/bin/env bash
# Flags string-concatenated or interpolated SQL — a classic injection footgun.
# Informational only — never blocks.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Skip files where this hook would noise (the plugin's own docs/scripts)
case "$FILE" in
  */hooks/scripts/*|*/docs/HOOKS.md|*/layers/*.eval.yaml) exit 0 ;;
esac

# Only inspect typical backend/source files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rb|*.java|*.php|*.cs) ;;
  *) exit 0 ;;
esac

FINDINGS=""

# Pattern 1: string-concat SQL — "SELECT ... " + var  OR  'SELECT ... ' + var
HIT=$(echo "$CONTENT" | grep -nE -i "['\"](SELECT|INSERT|UPDATE|DELETE|WHERE|FROM)\b[^'\"]*['\"][[:space:]]*\+" | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[concat] $HIT"

# Pattern 2: template literals interpolating into SQL — `SELECT ... ${var} ...`
HIT=$(echo "$CONTENT" | grep -nE -i "\`[^\`]*\b(SELECT|INSERT|UPDATE|DELETE|WHERE|FROM)\b[^\`]*\\\$\{" | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[template] $HIT"

# Pattern 3: Python f-strings into SQL — f"SELECT ... {var} ..."
HIT=$(echo "$CONTENT" | grep -nE -i 'f["'"'"'][^"'"'"']*\b(SELECT|INSERT|UPDATE|DELETE|WHERE|FROM)\b[^"'"'"']*\{' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[f-string] $HIT"

# Pattern 4: Python .format() on SQL — "SELECT ... {} ...".format(var)
HIT=$(echo "$CONTENT" | grep -nE -i "['\"][^'\"]*\b(SELECT|INSERT|UPDATE|DELETE|WHERE|FROM)\b[^'\"]*\{[0-9a-zA-Z_]*\}[^'\"]*['\"]\.format" | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[format] $HIT"

if [ -n "$FINDINGS" ]; then
  echo "🟡 sql-injection-pattern: potential SQL injection in $FILE — use parameterised queries / prepared statements:"
  echo -e "$FINDINGS" | head -10
fi

exit 0
