#!/usr/bin/env bash
# Validates Kubernetes manifests via kubeconform/kubeval if installed. Informational only.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
case "$FILE" in *.yml|*.yaml) ;; *) exit 0 ;; esac

# Only run for manifests in a k8s-shaped directory
case "$FILE" in
  */k8s/*|*/kubernetes/*|*/manifests/*|*/charts/*|*/deploy/*|*/helm/*) ;;
  *) exit 0 ;;
esac

# Quick heuristic: file must declare an apiVersion + kind
grep -qE '^apiVersion:' "$FILE" 2>/dev/null || exit 0
grep -qE '^kind:' "$FILE" 2>/dev/null || exit 0

RUNNER=""
if command -v kubeconform >/dev/null 2>&1; then
  RUNNER="kubeconform -strict -ignore-missing-schemas -summary"
elif command -v kubeval >/dev/null 2>&1; then
  RUNNER="kubeval --strict --ignore-missing-schemas"
else
  exit 0
fi

OUTPUT=$($RUNNER "$FILE" 2>&1 | head -20)
if echo "$OUTPUT" | grep -qiE 'invalid|error|fail'; then
  echo "🟡 k8s-manifest-validate findings for $FILE:"
  echo "$OUTPUT"
fi

exit 0
