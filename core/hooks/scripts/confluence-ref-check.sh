#!/usr/bin/env bash
# When the user's prompt mentions a documentation artifact (spec, RFC, ADR, runbook,
# design doc, postmortem), nudge to search the docs database via the relevant MCP.
# Informational only — never blocks. Fires on UserPromptSubmit.

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

# Match common doc-artifact keywords (case-insensitive, word boundaries best-effort)
if echo "$PROMPT" | grep -qiE '\b(spec|RFC|ADR|runbook|design[[:space:]]+doc|postmortem|post-mortem|wiki[[:space:]]+page|confluence[[:space:]]+page|notion[[:space:]]+page)\b'; then
  # Identify which MCP, if any, is wired up
  PROJECT_ROOT=$(pwd)
  AVAILABLE=""
  if [ -f "$PROJECT_ROOT/.mcp.json" ]; then
    grep -q '"confluence"' "$PROJECT_ROOT/.mcp.json" 2>/dev/null && AVAILABLE="$AVAILABLE Confluence(mcp__confluence__search_pages)"
    grep -q '"notion"' "$PROJECT_ROOT/.mcp.json" 2>/dev/null && AVAILABLE="$AVAILABLE Notion(mcp__notion__search)"
  fi
  AVAILABLE=$(echo "$AVAILABLE" | xargs)

  if [ -n "$AVAILABLE" ]; then
    echo "📚 confluence-ref-check: prompt mentions a doc artifact. Try searching first: $AVAILABLE"
  else
    echo "📚 confluence-ref-check: prompt mentions a doc artifact. No docs MCP appears to be wired in .mcp.json — consider running /setup to enable Confluence or Notion."
  fi
fi

exit 0
