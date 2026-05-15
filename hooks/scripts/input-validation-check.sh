#!/usr/bin/env bash
# Flags req.body / req.query / req.params access without a schema validation in the same file.
# Informational only — never blocks. Heuristic.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

# Only relevant in route/controller-shaped files
case "$FILE" in
  */routes/*|*/controllers/*|*/handlers/*|*/api/*|*routes.ts|*routes.js|*controller*) ;;
  *) exit 0 ;;
esac

# Look for raw req access
RAW=$(echo "$CONTENT" | grep -nE '\breq\.(body|query|params)\.[a-zA-Z_]' | head -5)
[ -z "$RAW" ] && exit 0

# If any validator is referenced in the file, accept
if echo "$CONTENT" | grep -qiE '\.(safeParse|parse)\s*\(|\.validate\s*\(|\.validateAsync\s*\(|joi\.|yup\.|z\.|class-validator|express-validator|@Body\(|ZodSchema|ValidationPipe'; then
  exit 0
fi

echo "🟡 input-validation-check: $FILE accesses req.body/query/params directly without a schema validator (zod/yup/joi/express-validator):"
echo "$RAW"

exit 0
