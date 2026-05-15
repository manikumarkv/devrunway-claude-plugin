#!/usr/bin/env bash
# Blocks `git commit` when the current branch is a protected branch.

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

echo "$CMD" | grep -qE '\bgit[[:space:]]+commit\b' || { echo '{"continue": true}'; exit 0; }

# Determine repo root from cwd
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo '{"continue": true}'; exit 0; }

BRANCH=$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null)
[ -z "$BRANCH" ] && { echo '{"continue": true}'; exit 0; }

case "$BRANCH" in
  main|master|develop|release|release/*)
    STOP="no-commit-to-main: refusing to commit directly to protected branch '$BRANCH'. Create a feature branch: git switch -c feat/<ticket>-<slug>"
    echo "{\"continue\": false, \"stopReason\": \"$STOP\"}"
    exit 0
    ;;
esac

echo '{"continue": true}'
exit 0
