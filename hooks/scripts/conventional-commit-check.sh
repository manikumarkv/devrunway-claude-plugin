#!/usr/bin/env bash
# Validates `git commit` messages follow the Conventional Commits format.
# Understands -m "..." / -m '...' / -am "..." and the heredoc form Claude Code
# uses: git commit -m "$(cat <<'EOF' ... EOF)". Editor-driven commits and
# messages it cannot evaluate statically pass through.
# Denies the single tool call so Claude sees the reason and can fix the message.

deny() {
  jq -nc --arg r "conventional-commit-check: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# Only target git commit with an inline message
printf '%s' "$CMD" | grep -qE '\bgit([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit\b' || exit 0
printf '%s' "$CMD" | grep -qE '([[:space:]]-[a-zA-Z]*m|--message)([[:space:]=]|")' || exit 0

if printf '%s' "$CMD" | grep -qE "<<-?[[:space:]]*['\"]?[A-Za-z_]+['\"]?"; then
  # Heredoc: the subject is the first non-blank line after the <<MARKER line.
  SUBJECT=$(printf '%s\n' "$CMD" | awk '
    found && NF { print; exit }
    /<<-?[[:space:]]*["'"'"']?[A-Za-z_]+/ { found = 1 }
  ' | sed -E 's/^[[:space:]]+//')
else
  MSG=$(printf '%s' "$CMD" | perl -0ne '
    if (/(?:\s-[a-zA-Z]*m|--message)[\s=]*"((?:[^"\\]|\\.)*)"/s) { print $1; exit }
    elsif (/(?:\s-[a-zA-Z]*m|--message)[\s=]*'\''([^'\'']*)'\''/s) { print $1; exit }
    elsif (/(?:\s-[a-zA-Z]*m|--message)[\s=]+(\S+)/) { print $1; exit }
  ')
  # Variables / command substitutions cannot be evaluated here: let them through.
  case "$MSG" in *'$'*|*'`'*) exit 0 ;; esac
  SUBJECT=$(printf '%s\n' "$MSG" | head -1)
fi

[ -z "$SUBJECT" ] && exit 0

# Validate format: type(scope)?: subject
TYPES='feat|fix|chore|docs|test|refactor|perf|style|build|ci|revert'
if ! printf '%s' "$SUBJECT" | grep -qE "^($TYPES)(\([a-zA-Z0-9._/-]+\))?!?: .+"; then
  deny "commit subject must follow 'type(scope): subject'. Allowed types: $TYPES. Example: 'feat(auth): add password reset'. Got: '$SUBJECT'"
fi

# Subject length
LEN=${#SUBJECT}
if [ "$LEN" -gt 72 ]; then
  deny "commit subject is $LEN chars; keep it ≤72. Move detail into the body."
fi

exit 0
