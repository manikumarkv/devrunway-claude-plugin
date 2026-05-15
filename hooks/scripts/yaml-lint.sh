#!/usr/bin/env bash
# Runs yamllint on the just-saved YAML file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.yml|*.yaml) ;; *) exit 0 ;; esac

command -v yamllint >/dev/null 2>&1 || exit 0

OUTPUT=$(yamllint -f parsable "$FILE" 2>&1 | head -20)
if [ -n "$OUTPUT" ]; then
  echo "🟡 yamllint findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
