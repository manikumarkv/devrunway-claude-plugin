#!/usr/bin/env bash
# Runs the test file(s) related to the just-edited source file.
# Informational only — never blocks. Skips silently when no obvious test exists.

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 0

# Normalise to repo-relative path
REL="${FILE#$ROOT/}"

# Determine target test file(s)
TARGETS=()

is_test_file() {
  case "$1" in
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx|*_test.py|test_*.py)
      return 0 ;;
  esac
  return 1
}

if is_test_file "$REL"; then
  TARGETS+=("$REL")
else
  # Strip extension
  case "$REL" in
    *.ts|*.tsx|*.js|*.jsx)
      base="${REL%.*}"
      for cand in "${base}.test.ts" "${base}.test.tsx" "${base}.spec.ts" "${base}.spec.tsx" \
                  "${base}.test.js" "${base}.test.jsx"; do
        [ -f "$cand" ] && TARGETS+=("$cand")
      done
      ;;
    *.py)
      base="${REL%.py}"
      name=$(basename "$base")
      dir=$(dirname "$base")
      for cand in "${dir}/test_${name}.py" "${dir}/${name}_test.py" "tests/test_${name}.py"; do
        [ -f "$cand" ] && TARGETS+=("$cand")
      done
      ;;
    *) exit 0 ;;
  esac
fi

[ ${#TARGETS[@]} -eq 0 ] && exit 0

# Pick runner
RUNNER=""
case "${TARGETS[0]}" in
  *.ts|*.tsx|*.js|*.jsx)
    if ls vitest.config.* 2>/dev/null | grep -q .; then
      RUNNER="vitest"
    elif ls jest.config.* 2>/dev/null | grep -q . || (command -v node >/dev/null && node -e "require('./package.json').jest" 2>/dev/null); then
      RUNNER="jest"
    fi
    ;;
  *.py)
    command -v pytest >/dev/null 2>&1 && RUNNER="pytest"
    ;;
esac

[ -z "$RUNNER" ] && exit 0
command -v npx >/dev/null 2>&1 || [ "$RUNNER" = "pytest" ] || exit 0

case "$RUNNER" in
  vitest)
    OUTPUT=$(npx --no-install vitest run "${TARGETS[@]}" --reporter=default 2>&1 | tail -20)
    ;;
  jest)
    OUTPUT=$(npx --no-install jest "${TARGETS[@]}" --silent 2>&1 | tail -20)
    ;;
  pytest)
    OUTPUT=$(pytest -q "${TARGETS[@]}" 2>&1 | tail -20)
    ;;
esac

if [ -n "$OUTPUT" ]; then
  echo "🧪 Focused tests for $REL:"
  echo "$OUTPUT"
fi

exit 0
