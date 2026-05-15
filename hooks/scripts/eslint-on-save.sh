#!/usr/bin/env bash
# Runs ESLint on the just-saved JS/TS file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

# Only run for JS/TS files
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Need an eslint config to run
CONFIG=""
for c in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
         .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
  [ -f "$ROOT/$c" ] && { CONFIG="$c"; break; }
done
[ -z "$CONFIG" ] && exit 0

# Need eslint to be installed (local or global)
command -v npx >/dev/null 2>&1 || exit 0

cd "$ROOT" || exit 0

OUTPUT=$(npx --no-install eslint --quiet --no-warn-ignored "$FILE" 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ] && [ -n "$OUTPUT" ]; then
  echo "🟡 ESLint findings for $FILE:"
  echo "$OUTPUT" | head -30
fi

exit 0
