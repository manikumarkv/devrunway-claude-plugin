#!/usr/bin/env bash
# Blocks `rm -rf` against high-risk paths (HOME, /, parent dirs, paths outside repo).
# Allows rm -rf inside the project tree (node_modules, dist, etc.).

CMD=$(jq -r '.tool_input.command // empty' 2>/dev/null)

# Only inspect rm -rf invocations
echo "$CMD" | grep -qE '\brm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*f' || { echo '{"continue": true}'; exit 0; }

# Extract paths (anything after rm -rf flags)
PATHS=$(echo "$CMD" | grep -oE 'rm[[:space:]]+-[a-zA-Z]+[[:space:]]+[^|;&]+' | sed -E 's/^rm[[:space:]]+-[a-zA-Z]+[[:space:]]+//')

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOME_EXPANDED="${HOME%/}"

for raw in $PATHS; do
  # Strip quotes
  p="${raw//\"/}"
  p="${p//\'/}"

  # High-risk literal matches
  case "$p" in
    /|/*|"$HOME"|"$HOME/"|"~"|"~/"|"\$HOME"|"\$HOME/")
      echo '{"continue": false, "stopReason": "destructive-rm-guard: refusing rm -rf against root/home/system path. Run manually if you are certain."}'
      exit 0
      ;;
  esac

  # Parent traversal
  case "$p" in
    ../*|*/../*|..)
      echo '{"continue": false, "stopReason": "destructive-rm-guard: refusing rm -rf with parent-directory traversal."}'
      exit 0
      ;;
  esac

  # Expand $HOME and ~ for absolute-path check
  expanded="${p/#\~/$HOME_EXPANDED}"
  expanded="${expanded//\$HOME/$HOME_EXPANDED}"

  # Reject anything that resolves to HOME or above
  if [[ "$expanded" == "$HOME_EXPANDED" || "$expanded" == "$HOME_EXPANDED/" ]]; then
    echo '{"continue": false, "stopReason": "destructive-rm-guard: refusing rm -rf against $HOME."}'
    exit 0
  fi

  # If absolute and outside repo root, block
  if [[ "$expanded" == /* && "$expanded" != "$REPO_ROOT"* ]]; then
    echo "{\"continue\": false, \"stopReason\": \"destructive-rm-guard: refusing rm -rf against path outside repo ($expanded). Repo root: $REPO_ROOT\"}"
    exit 0
  fi
done

echo '{"continue": true}'
exit 0
