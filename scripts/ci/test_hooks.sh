#!/usr/bin/env bash
# Behaviour tests for the blocking hooks: feed each one a fake tool-call
# payload on stdin and assert whether it blocks ("continue": false).
# Run from the repo root.

set -u
HOOKS="hooks/scripts"
PASS=0
FAIL=0

# expect <block|allow> <script> <description> <json-payload>
expect() {
  local want="$1" script="$2" desc="$3" payload="$4" out got
  out=$(printf '%s' "$payload" | bash "$HOOKS/$script" 2>/dev/null)
  if printf '%s' "$out" | jq -e '.continue == false' >/dev/null 2>&1; then
    got=block
  else
    got=allow
  fi
  if [ "$got" = "$want" ]; then
    PASS=$((PASS + 1))
    echo "ok    $script: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL  $script: $desc (expected $want, got $got; output: $out)"
    [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::error file=$HOOKS/$script::$desc — expected $want, got $got"
  fi
}

bash_cmd() { jq -nc --arg c "$1" --arg d "${2:-$PWD}" '{tool_input:{command:$c}, cwd:$d}'; }
write_file() { jq -nc --arg f "$1" --arg c "$2" '{tool_input:{file_path:$f, content:$c}}'; }

# --- destructive-git-guard -------------------------------------------------
expect block destructive-git-guard.sh "force push"         "$(bash_cmd 'git push --force origin main')"
expect block destructive-git-guard.sh "reset --hard"       "$(bash_cmd 'git reset --hard HEAD~1')"
expect block destructive-git-guard.sh "clean -fd"          "$(bash_cmd 'git clean -fd')"
expect allow destructive-git-guard.sh "normal push"        "$(bash_cmd 'git push -u origin feat/x')"
expect allow destructive-git-guard.sh "git status"         "$(bash_cmd 'git status')"

# --- destructive-rm-guard --------------------------------------------------
expect block destructive-rm-guard.sh "rm -rf /"            "$(bash_cmd 'rm -rf /')"
expect block destructive-rm-guard.sh "rm -rf ~"            "$(bash_cmd 'rm -rf ~')"
expect block destructive-rm-guard.sh "rm -rf \$HOME"       "$(bash_cmd 'rm -rf $HOME')"
expect block destructive-rm-guard.sh "parent traversal"    "$(bash_cmd 'rm -rf ../other')"
expect allow destructive-rm-guard.sh "node_modules in repo" "$(bash_cmd 'rm -rf node_modules')"
expect allow destructive-rm-guard.sh "non-recursive rm"    "$(bash_cmd 'rm file.txt')"

# --- conventional-commit-check ---------------------------------------------
expect allow conventional-commit-check.sh "valid feat"     "$(bash_cmd 'git commit -m "feat(auth): add reset"')"
expect allow conventional-commit-check.sh "valid chore"    "$(bash_cmd 'git commit -m "chore(plugin): bump"')"
expect block conventional-commit-check.sh "no type prefix" "$(bash_cmd 'git commit -m "added stuff"')"
expect block conventional-commit-check.sh "unknown type"   "$(bash_cmd 'git commit -m "feature: add x"')"
expect block conventional-commit-check.sh "subject > 72"   "$(bash_cmd "git commit -m \"feat: $(printf 'x%.0s' {1..80})\"")"
expect allow conventional-commit-check.sh "not a commit"   "$(bash_cmd 'git log -1')"

# --- no-commit-to-main -----------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q -b main main-repo
git -C "$TMP" init -q -b feat/x feature-repo
expect block no-commit-to-main.sh "commit on main"         "$(bash_cmd 'git commit -m "feat: x"' "$TMP/main-repo")"
expect allow no-commit-to-main.sh "commit on feature"      "$(bash_cmd 'git commit -m "feat: x"' "$TMP/feature-repo")"
expect allow no-commit-to-main.sh "non-commit on main"     "$(bash_cmd 'git status' "$TMP/main-repo")"

# --- secrets-leak-guard ----------------------------------------------------
# Fixtures are assembled at runtime so this file never contains a literal
# secret pattern (which secrets-leak-guard itself would block).
AWS="AKIA""ABCDEFGHIJKLMNOP"
GHP="ghp_""$(printf 'a%.0s' {1..36})"
PEM="-----BEGIN RSA ""PRIVATE KEY-----"
JWT="eyJ""hbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
expect block secrets-leak-guard.sh "AWS key in .ts"        "$(write_file src/config.ts "const k = '$AWS'")"
expect block secrets-leak-guard.sh "GitHub PAT in .env.ts" "$(write_file src/env.ts "token=$GHP")"
expect block secrets-leak-guard.sh "private key"           "$(write_file keys/id.txt "$PEM")"
expect block secrets-leak-guard.sh "JWT in code"           "$(write_file src/a.ts "const t = '$JWT'")"
expect allow secrets-leak-guard.sh "example key in docs"   "$(write_file README.md "Example: $AWS")"
expect allow secrets-leak-guard.sh "clean file"            "$(write_file src/a.ts "export const x = 1")"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
