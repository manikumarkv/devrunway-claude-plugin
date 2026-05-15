#!/usr/bin/env bash
# Runs prettier --check on the just-saved file. Informational only — never blocks.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

# Only files Prettier typically formats
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.less|*.html|*.md|*.mdx|*.yml|*.yaml|*.vue) ;;
  *) exit 0 ;;
esac

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Need a prettier config to run
CONFIG=""
for c in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs .prettierrc.mjs \
         .prettierrc.yml .prettierrc.yaml prettier.config.js prettier.config.cjs prettier.config.mjs; do
  [ -f "$ROOT/$c" ] && { CONFIG="$c"; break; }
done

# Also check package.json for a "prettier" key
if [ -z "$CONFIG" ] && [ -f "$ROOT/package.json" ]; then
  if grep -q '"prettier"' "$ROOT/package.json"; then
    CONFIG="package.json"
  fi
fi
[ -z "$CONFIG" ] && exit 0

command -v npx >/dev/null 2>&1 || exit 0

cd "$ROOT" || exit 0

OUTPUT=$(npx --no-install prettier --check "$FILE" 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo "🟡 Prettier formatting issue in $FILE — run: npx prettier --write \"$FILE\""
fi

exit 0
