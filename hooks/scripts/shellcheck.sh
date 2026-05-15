#!/usr/bin/env bash
# Runs shellcheck on the just-saved shell script. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in
  *.sh|*.bash) ;;
  *)
    # Detect by shebang for extensionless scripts
    [ -f "$FILE" ] && head -1 "$FILE" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' || exit 0
    ;;
esac

command -v shellcheck >/dev/null 2>&1 || exit 0

OUTPUT=$(shellcheck -f gcc "$FILE" 2>&1 | head -20)
if [ -n "$OUTPUT" ]; then
  echo "🟡 shellcheck findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
