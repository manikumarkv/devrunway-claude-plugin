#!/usr/bin/env bash
# Blocks recursive+forced rm against high-risk paths (/, system dirs, HOME,
# parent traversal, absolute paths outside the project). Allows rm -rf inside
# the project tree (node_modules, dist, etc.). Denies the single tool call so
# Claude sees the reason, rather than ending the turn.

INPUT=$(cat)
set -f  # never glob-expand the command's words (rm -rf * must stay literal)

deny() {
  jq -nc --arg r "destructive-rm-guard: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

PROJECT=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
ROOT=$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT")
HOME_DIR="${HOME%/}"

# Drop quoted text so `echo "rm -rf /"` or a commit message does not match.
BARE=$(printf '%s' "$CMD" | tr '\n' ' ' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

while IFS= read -r seg; do
  # shellcheck disable=SC2206
  words=($seg)
  # Find the rm word (allow sudo / env prefixes).
  i=0
  while [ $i -lt ${#words[@]} ] && [ "${words[$i]}" != "rm" ]; do i=$((i + 1)); done
  [ $i -lt ${#words[@]} ] || continue

  recursive=0 force=0 targets=()
  for w in "${words[@]:$((i + 1))}"; do
    case "$w" in
      --recursive) recursive=1 ;;
      --force) force=1 ;;
      --) ;;
      --*) ;;
      -*)
        [[ "$w" == *[rR]* ]] && recursive=1
        [[ "$w" == *f* ]] && force=1 ;;
      *) targets+=("$w") ;;
    esac
  done
  [ $recursive -eq 1 ] && [ $force -eq 1 ] || continue

  for t in "${targets[@]}"; do
    # Literal patterns on purpose: these are the unexpanded words Claude typed.
    # shellcheck disable=SC2088
    case "$t" in
      '*'|'/*'|'~'|'~/'|'~/*'|'$HOME'|'$HOME/'|'${HOME}'|/|/bin*|/boot*|/dev*|/etc*|/lib*|/opt*|/proc*|/root*|/sbin*|/sys*|/usr*|/var*|/home|/home/|/Users|/Users/)
        deny "refusing rm -rf on '$t' (root, system, home or wildcard path). Ask the user to run it manually if intended." ;;
    esac
    case "$t" in
      ..|../*|*/..|*/../*)
        deny "refusing rm -rf with parent-directory traversal ('$t'). Use a path inside the project." ;;
    esac

    expanded="${t/#\~/$HOME_DIR}"
    expanded="${expanded//\$HOME/$HOME_DIR}"
    expanded="${expanded//\$\{HOME\}/$HOME_DIR}"
    expanded="${expanded%/}"
    if [ "$expanded" = "$HOME_DIR" ]; then
      deny "refusing rm -rf on \$HOME."
    fi
    # Scratch space under /tmp is fine; /tmp itself is not.
    [[ "$expanded" == /tmp/?* || "$expanded" == /private/tmp/?* ]] && continue
    if [[ "$expanded" == /* && "$expanded" != "$ROOT" && "$expanded" != "$ROOT"/* ]]; then
      deny "refusing rm -rf on '$expanded', which is outside the project ($ROOT). Ask the user to run it manually."
    fi
  done
done < <(printf '%s\n' "$BARE" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
