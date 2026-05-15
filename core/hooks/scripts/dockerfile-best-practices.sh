#!/usr/bin/env bash
# Flags common Dockerfile anti-patterns: latest tag, no USER, ADD for local files, no HEALTHCHECK.
# Informational only — never blocks.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

case "$FILE" in
  */Dockerfile|*/Dockerfile.*|Dockerfile|Dockerfile.*|*.dockerfile) ;;
  *) exit 0 ;;
esac

FINDINGS=""

# FROM image:latest or FROM image (no tag)
HIT=$(echo "$CONTENT" | grep -nE '^[[:space:]]*FROM[[:space:]]+[^[:space:]]+:latest\b' | head -2)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[latest-tag] $HIT"
HIT=$(echo "$CONTENT" | grep -nE '^[[:space:]]*FROM[[:space:]]+[^[:space:]@:]+([[:space:]]+as[[:space:]]|$)' | head -2)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[no-tag] $HIT"

# ADD used for local paths (use COPY) — ADD https?:// or .tar are legitimate
HIT=$(echo "$CONTENT" | grep -nE '^[[:space:]]*ADD[[:space:]]+' | grep -vE 'https?://|ftp://|\.tar\b' | head -2)
[ -n "$HIT" ] && FINDINGS="$FINDINGS\n[ADD-for-local] $HIT"

# Missing USER (likely root)
if ! echo "$CONTENT" | grep -qE '^[[:space:]]*USER[[:space:]]+'; then
  FINDINGS="$FINDINGS\n[no-USER] image runs as root — add a non-root USER directive"
fi

# Missing HEALTHCHECK
if ! echo "$CONTENT" | grep -qE '^[[:space:]]*HEALTHCHECK[[:space:]]+'; then
  FINDINGS="$FINDINGS\n[no-HEALTHCHECK] no HEALTHCHECK directive — orchestrators won't know when the container is ready"
fi

# apt-get without --no-install-recommends or && rm -rf /var/lib/apt/lists/*
if echo "$CONTENT" | grep -qE 'apt-get[[:space:]]+install'; then
  if ! echo "$CONTENT" | grep -qE 'rm[[:space:]]+-rf[[:space:]]+/var/lib/apt/lists'; then
    FINDINGS="$FINDINGS\n[apt-cache] apt-get install without cleanup — bloats image; add 'rm -rf /var/lib/apt/lists/*'"
  fi
fi

if [ -n "$FINDINGS" ]; then
  echo "🟡 dockerfile-best-practices findings for $FILE:"
  echo -e "$FINDINGS" | head -15
fi

exit 0
