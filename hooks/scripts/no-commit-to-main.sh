#!/usr/bin/env bash
# Blocks `git commit` when the *project's* current branch is protected.
# Denies the single tool call so Claude sees the reason, rather than ending the turn.
#
# Opt-in per project, so a user-level install is safe in personal and
# trunk-based repos: enforced only when stack.json sets
#   "policies": {"protect-main": true}

INPUT=$(cat)

deny() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
echo "$CMD" | grep -qE '\bgit[[:space:]]+commit\b' || exit 0

# Resolve the repo from the session's project directory, never from the ambient
# cwd. Hooks may execute with a working directory inside the plugin marketplace
# checkout (~/.claude/plugins/marketplaces/<name>), which is itself a git repo
# on `main` — resolving from cwd there reports branch `main` and blocks every
# commit, including ones made on a perfectly valid feature branch.
PROJECT_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT_DIR" ] && PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ "$(jq -r '.policies["protect-main"] // empty' "$ROOT/stack.json" 2>/dev/null)" = "true" ] || exit 0

BRANCH=$(git -C "$ROOT" symbolic-ref --short HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

case "$BRANCH" in
  main|master|develop|release|release/*)
    deny "no-commit-to-main: refusing to commit directly to protected branch '$BRANCH'. Create a feature branch first: git switch -c feat/<ticket>-<slug>"
    ;;
esac

exit 0
