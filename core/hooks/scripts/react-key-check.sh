#!/usr/bin/env bash
# Flags .map(... => <Component ...>) without a `key=` prop on the returned element.
# Informational only — never blocks. Heuristic.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0
case "$FILE" in *.tsx|*.jsx) ;; *) exit 0 ;; esac

# Heuristic: find a line containing `.map(...` followed by JSX `<Identifier` without `key=`
# Limitation: multi-line arrow returns get scanned via a simple "next two lines" window using awk.
HITS=$(echo "$CONTENT" | awk '
  /\.map[[:space:]]*\(/ {
    window = $0
    for (i=1; i<=2 && (getline next_line) > 0; i++) window = window "\n" next_line
    if (window ~ /<[A-Z][A-Za-z0-9]*/ && window !~ /key[[:space:]]*=/) {
      print NR ": " $0
    }
  }
' | head -5)

if [ -n "$HITS" ]; then
  echo "🟡 react-key-check: .map() that renders JSX without a key= prop in $FILE:"
  echo "$HITS"
fi

exit 0
