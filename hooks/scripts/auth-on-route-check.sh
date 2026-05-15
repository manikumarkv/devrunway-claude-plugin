#!/usr/bin/env bash
# Flags route handlers that don't reference an auth middleware/decorator.
# Informational only — never blocks. Heuristic — backend stacks only.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Only inspect typical route / controller files
case "$FILE" in
  */routes/*|*/controllers/*|*/handlers/*|*/api/*|*routes.ts|*routes.js|*routes.py|*router.ts|*router.py) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go) ;;
  *) exit 0 ;;
esac

# Skip if the file is the auth middleware itself
case "$FILE" in
  *auth*|*authn*|*authz*|*middleware*|*public*|*health*|*login*|*signup*|*register*) exit 0 ;;
esac

# Look for route declarations
ROUTE_HITS=$(echo "$CONTENT" | grep -nE '\b(app|router)\.(get|post|put|patch|delete)\s*\(|@(app|router)\.(route|get|post|put|patch|delete)\(|@(Get|Post|Put|Patch|Delete)\(' | head -10)

[ -z "$ROUTE_HITS" ] && exit 0

# If auth middleware/keyword is referenced anywhere in the file, assume it's wired up
if echo "$CONTENT" | grep -qiE '\b(requireAuth|isAuthenticated|authenticate|authMiddleware|jwtRequired|loginRequired|UseGuards|@auth|verifyToken|Depends\(get_current_user|@PreAuthorize|ensureAuth)\b'; then
  exit 0
fi

echo "🟡 auth-on-route-check: route handlers in $FILE don't appear to apply an auth middleware. If they're meant to be public, ignore; otherwise add requireAuth / @auth / isAuthenticated."
echo "$ROUTE_HITS" | head -5

exit 0
