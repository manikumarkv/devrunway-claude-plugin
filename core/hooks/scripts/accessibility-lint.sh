#!/usr/bin/env bash
# Runs eslint jsx-a11y rules on the just-saved JSX/TSX file. Informational only.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.tsx|*.jsx) ;; *) exit 0 ;; esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Need an eslint config
HAS_CONFIG=0
for c in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
         .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
  [ -f "$ROOT/$c" ] && { HAS_CONFIG=1; break; }
done
[ "$HAS_CONFIG" = "0" ] && exit 0

# Need jsx-a11y plugin installed (presence of node_modules entry is the cheap check)
[ -d "$ROOT/node_modules/eslint-plugin-jsx-a11y" ] || exit 0

command -v npx >/dev/null 2>&1 || exit 0
cd "$ROOT" || exit 0

OUTPUT=$(npx --no-install eslint --quiet --no-warn-ignored --rulesdir node_modules/eslint-plugin-jsx-a11y "$FILE" 2>&1 | grep -E 'jsx-a11y/' | head -20)

if [ -n "$OUTPUT" ]; then
  echo "🟡 accessibility-lint findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
