#!/usr/bin/env bash
# Blocks Write/Edit operations whose payload contains high-confidence secret patterns.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

# Nothing to inspect
[ -z "$CONTENT" ] && { echo '{"continue": true}'; exit 0; }

# Skip the plugin's own hook + skill files (they describe these patterns)
case "$FILE" in
  */hooks/scripts/*|*/core/agents/*|*/docs/HOOKS.md|*/CAPABILITIES.md|*/docs/CAPABILITIES.md)
    echo '{"continue": true}'; exit 0 ;;
esac

# High-confidence patterns
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                              # AWS access key id
  'ghp_[A-Za-z0-9]{36,}'                          # GitHub PAT (classic personal)
  'gho_[A-Za-z0-9]{36,}'                          # GitHub OAuth
  'ghu_[A-Za-z0-9]{36,}'                          # GitHub user-to-server
  'ghs_[A-Za-z0-9]{36,}'                          # GitHub server-to-server
  'ghr_[A-Za-z0-9]{36,}'                          # GitHub refresh
  'sk_live_[A-Za-z0-9]{24,}'                      # Stripe live secret
  'rk_live_[A-Za-z0-9]{24,}'                      # Stripe live restricted
  '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  'xox[abprs]-[A-Za-z0-9-]{10,}'                  # Slack tokens
  'AIza[0-9A-Za-z_-]{35}'                         # Google API key
)

# Markdown docs: allow obvious examples (EXAMPLE / example.com / fake)
IS_DOC=0
case "$FILE" in *.md|*.mdx|*.markdown) IS_DOC=1 ;; esac

for pat in "${PATTERNS[@]}"; do
  MATCH=$(echo "$CONTENT" | grep -oE -e "$pat" | head -1)
  if [ -n "$MATCH" ]; then
    if [ "$IS_DOC" = "1" ]; then
      # Allow if the matched line/context is clearly an example
      LINE=$(echo "$CONTENT" | grep -F -e "$MATCH" | head -1)
      if echo "$LINE" | grep -qiE 'example|EXAMPLE|fake|placeholder|<your|YOUR_'; then
        continue
      fi
    fi
    REDACTED=$(echo "$MATCH" | cut -c1-8)
    echo "{\"continue\": false, \"stopReason\": \"secrets-leak-guard: refused to write a likely secret to $FILE (pattern '${REDACTED}…'). Move it to a .env file or a secret manager.\"}"
    exit 0
  fi
done

# Generic JWT — looser, so check separately and skip in markdown
if [ "$IS_DOC" = "0" ]; then
  if echo "$CONTENT" | grep -qE 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'; then
    echo "{\"continue\": false, \"stopReason\": \"secrets-leak-guard: refused to write what looks like a JWT to $FILE. Don't commit real tokens — use placeholders or .env.\"}"
    exit 0
  fi
fi

echo '{"continue": true}'
exit 0
