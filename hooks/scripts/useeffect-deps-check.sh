#!/usr/bin/env bash
# Runs eslint react-hooks/exhaustive-deps on the just-saved file. Informational only.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.tsx|*.jsx|*.ts|*.js) ;; *) exit 0 ;; esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

HAS_CONFIG=0
for c in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
         .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json; do
  [ -f "$ROOT/$c" ] && { HAS_CONFIG=1; break; }
done
[ "$HAS_CONFIG" = "0" ] && exit 0

[ -d "$ROOT/node_modules/eslint-plugin-react-hooks" ] || exit 0

command -v npx >/dev/null 2>&1 || exit 0
cd "$ROOT" || exit 0

OUTPUT=$(npx --no-install eslint --quiet --no-warn-ignored --rule 'react-hooks/exhaustive-deps: warn' "$FILE" 2>&1 | grep -E 'exhaustive-deps|react-hooks' | head -10)

if [ -n "$OUTPUT" ]; then
  echo "🟡 useEffect-deps-check findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
