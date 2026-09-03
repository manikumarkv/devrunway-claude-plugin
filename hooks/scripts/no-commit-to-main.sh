#!/usr/bin/env bash
# Blocks `git commit` when the *project's* current branch is protected.

INPUT=$(cat)

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
echo "$CMD" | grep -qE '\bgit[[:space:]]+commit\b' || { echo '{"continue": true}'; exit 0; }

# Resolve the repo from the session's project directory, never from the ambient
# cwd. Hooks may execute with a working directory inside the plugin marketplace
# checkout (~/.claude/plugins/marketplaces/<name>), which is itself a git repo
# on `main` — resolving from cwd there reports branch `main` and blocks every
# commit, including ones made on a perfectly valid feature branch.
PROJECT_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT_DIR" ] && PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || { echo '{"continue": true}'; exit 0; }

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
