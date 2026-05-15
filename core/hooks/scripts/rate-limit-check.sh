#!/usr/bin/env bash
# Flags new route declarations in files that don't reference any rate-limit middleware.
# Informational only — never blocks. Heuristic.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

case "$FILE" in
  */routes/*|*/controllers/*|*/handlers/*|*/api/*|*routes.ts|*routes.js|*routes.py|*router.ts|*router.py) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go) ;;
  *) exit 0 ;;
esac

# Look for any route declaration
ROUTES=$(echo "$CONTENT" | grep -cE '\b(app|router)\.(get|post|put|patch|delete)\s*\(|@(app|router)\.(route|get|post|put|patch|delete)\(|@(Get|Post|Put|Patch|Delete)\(')
[ "$ROUTES" -eq 0 ] && exit 0

# If a rate-limit middleware is referenced anywhere in the file or imported, accept
if echo "$CONTENT" | grep -qiE '\b(rateLimit|rate-limit|RateLimiter|express-rate-limit|slowDown|throttle|SlowAPI|Limiter|@Throttle)\b'; then
  exit 0
fi

echo "🟡 rate-limit-check: $FILE declares routes but no rate-limit middleware was found. Consider express-rate-limit / SlowAPI / @Throttle on public endpoints."

exit 0
