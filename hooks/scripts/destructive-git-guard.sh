#!/usr/bin/env bash
# Blocks destructive git commands before they execute.
# Denies the single tool call (Claude sees the reason and can adjust) rather
# than ending the turn. rm -rf is handled by destructive-rm-guard.sh.

deny() {
  jq -nc --arg r "destructive-git-guard: $1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

# Drop quoted text (commit messages, echo/grep arguments, heredoc bodies passed
# via "$(cat <<EOF ...)") so a message that *mentions* a command does not match.
BARE=$(printf '%s' "$CMD" | tr '\n' ' ' | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

# Split on shell separators and inspect each git invocation on its own.
while IFS= read -r seg; do
  # Normalise "git -C dir" / "git -c k=v" prefixes and repeated spaces.
  seg=$(printf '%s' "$seg" | sed -E 's/[[:space:]]+/ /g; s/^ //')
  printf '%s' "$seg" | grep -qE '(^|[ /])git( |$)' || continue
  args=$(printf '%s' "$seg" | sed -E 's/.*(^|[ /])git //; s/(-C|-c) [^ ]+ //g')
  sub=${args%% *}
  rest=" ${args#* } "

  case "$sub" in
    push)
      if printf '%s' "$rest" | grep -qE ' (-f|--force|-[a-zA-Z]*f[a-zA-Z]*) ' ||
         printf '%s' "$rest" | grep -qE ' \+[^ ]+'; then
        deny "force push rewrites remote history. Use --force-with-lease if you must, or ask the user to run it."
      fi ;;
    reset)
      printf '%s' "$rest" | grep -qE ' --hard ' &&
        deny "git reset --hard discards uncommitted work. Use git stash or git reset --keep, or ask the user." ;;
    clean)
      printf '%s' "$rest" | grep -qE ' (-[a-zA-Z]*f[a-zA-Z]*|--force) ' &&
        deny "git clean -f permanently deletes untracked files. List them with git clean -n and ask the user." ;;
    branch)
      printf '%s' "$rest" | grep -qE ' (-D|--delete --force|-d --force|-df|-fd) ' &&
        deny "git branch -D deletes a branch even if unmerged. Use git branch -d, or ask the user." ;;
  esac
done < <(printf '%s\n' "$BARE" | sed -E 's/(&&|\|\||;|\|)/\n/g')

exit 0
