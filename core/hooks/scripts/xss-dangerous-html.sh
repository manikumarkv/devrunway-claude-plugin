#!/usr/bin/env bash
# Flags introduction of XSS-prone HTML APIs: dangerouslySetInnerHTML, v-html, innerHTML =, document.write(
# Informational only — never blocks.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Skip the plugin's own docs/scripts
case "$FILE" in
  */hooks/scripts/*|*/docs/HOOKS.md|*/layers/*) exit 0 ;;
esac

# Only inspect frontend / template files
case "$FILE" in
  *.tsx|*.jsx|*.ts|*.js|*.vue|*.svelte|*.html|*.htm) ;;
  *) exit 0 ;;
esac

FINDINGS=""

HIT=$(echo "$CONTENT" | grep -nE 'dangerouslySetInnerHTML' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[react] $HIT"

HIT=$(echo "$CONTENT" | grep -nE '\bv-html[[:space:]]*=' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[vue] $HIT"

HIT=$(echo "$CONTENT" | grep -nE '\.(innerHTML|outerHTML)[[:space:]]*=' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[dom] $HIT"

HIT=$(echo "$CONTENT" | grep -nE '\bdocument\.write[ln]?\(' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[doc.write] $HIT"

# Svelte: {@html ...}
HIT=$(echo "$CONTENT" | grep -nE '\{@html[[:space:]]' | head -3)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[svelte] $HIT"

if [ -n "$FINDINGS" ]; then
  echo "🟡 xss-dangerous-html: unsafe HTML insertion in $FILE — sanitise the input (DOMPurify) or render as text:"
  echo -e "$FINDINGS" | head -10
fi

exit 0
