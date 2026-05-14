#!/usr/bin/env bash
# Prints a branch and commit summary at the end of every Claude session.
# Exits silently if not inside a git repository.

BRANCH=$(git branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

CHANGES=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
RECENT=$(git log develop..HEAD --oneline 2>/dev/null | head -5)

echo ""
echo "── Session end ──────────────────"
echo "Branch:  $BRANCH"
echo "Changed: $CHANGES file(s) uncommitted"

if [ -n "$RECENT" ]; then
  echo "Commits ahead of develop:"
  echo "$RECENT" | sed 's/^/  /'
fi

echo "─────────────────────────────────"
exit 0
