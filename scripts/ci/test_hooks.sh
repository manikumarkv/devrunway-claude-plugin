#!/usr/bin/env bash
# Behaviour tests for the blocking hooks: feed each one a fake tool-call
# payload on stdin and assert whether it denies the call
# (hookSpecificOutput.permissionDecision == "deny").
# Run from the repo root.

set -u
HOOKS="hooks/scripts"
PASS=0
FAIL=0

# expect <block|allow> <script> <description> <json-payload>
expect() {
  local want="$1" script="$2" desc="$3" payload="$4" out got
  out=$(printf '%s' "$payload" | bash "$HOOKS/$script" 2>/dev/null)
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
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

# Claude Code's standard commit form: git commit -m "$(cat <<'EOF' ... EOF)"
heredoc_commit() { printf 'git commit -m "$(cat <<%sEOF%s\n%s\n\nBody text.\nEOF\n)"' "'" "'" "$1"; }

# Every blocking hook must speak the deny protocol, never end the turn.
for h in destructive-git-guard destructive-rm-guard conventional-commit-check no-commit-to-main secrets-leak-guard; do
  if grep -q '"continue": false' "$HOOKS/$h.sh"; then
    FAIL=$((FAIL + 1)); echo "FAIL  $h.sh: still emits {\"continue\": false}, which ends Claude's turn"
  else
    PASS=$((PASS + 1)); echo "ok    $h.sh: uses permissionDecision deny"
  fi
done

# --- destructive-git-guard -------------------------------------------------
expect block destructive-git-guard.sh "force push"         "$(bash_cmd 'git push --force origin main')"
expect block destructive-git-guard.sh "push -f"            "$(bash_cmd 'git push -f origin main')"
expect block destructive-git-guard.sh "push +refspec"      "$(bash_cmd 'git push origin +main')"
expect block destructive-git-guard.sh "git -C dir push -f" "$(bash_cmd 'git -C ../x push --force')"
expect block destructive-git-guard.sh "chained push -f"    "$(bash_cmd 'git status && git push -f')"
expect block destructive-git-guard.sh "reset --hard"       "$(bash_cmd 'git reset --hard HEAD~1')"
expect block destructive-git-guard.sh "reset  --hard (2 spaces)" "$(bash_cmd 'git reset  --hard')"
expect block destructive-git-guard.sh "clean -fd"          "$(bash_cmd 'git clean -fd')"
expect block destructive-git-guard.sh "branch -D"          "$(bash_cmd 'git branch -D feat')"
expect allow destructive-git-guard.sh "force-with-lease"   "$(bash_cmd 'git push --force-with-lease')"
expect allow destructive-git-guard.sh "normal push"        "$(bash_cmd 'git push -u origin feat/x')"
expect allow destructive-git-guard.sh "git status"         "$(bash_cmd 'git status')"
expect allow destructive-git-guard.sh "branch -d"          "$(bash_cmd 'git branch -d feat')"
expect allow destructive-git-guard.sh "clean -n (dry run)" "$(bash_cmd 'git clean -n')"
expect allow destructive-git-guard.sh "message mentions reset --hard" "$(bash_cmd 'git commit -m "docs: explain git reset --hard"')"
expect allow destructive-git-guard.sh "grep for force push" "$(bash_cmd 'grep -r "git push --force" .')"
expect allow destructive-git-guard.sh "rm -rf node_modules (not its job)" "$(bash_cmd 'rm -rf node_modules')"

# --- destructive-rm-guard --------------------------------------------------
expect block destructive-rm-guard.sh "rm -rf /"            "$(bash_cmd 'rm -rf /')"
expect block destructive-rm-guard.sh "rm -rf ~"            "$(bash_cmd 'rm -rf ~')"
expect block destructive-rm-guard.sh "rm -rf \$HOME"       "$(bash_cmd 'rm -rf $HOME')"
expect block destructive-rm-guard.sh "parent traversal"    "$(bash_cmd 'rm -rf ../other')"
expect block destructive-rm-guard.sh "rm -fr ~ (flag order)" "$(bash_cmd 'rm -fr ~')"
expect block destructive-rm-guard.sh "rm -r -f / (split flags)" "$(bash_cmd 'rm -r -f /')"
expect block destructive-rm-guard.sh "rm -Rf /"            "$(bash_cmd 'rm -Rf /')"
expect block destructive-rm-guard.sh "rm --recursive --force /" "$(bash_cmd 'rm --recursive --force /')"
expect block destructive-rm-guard.sh "sudo rm -rf /usr"    "$(bash_cmd 'sudo rm -rf /usr')"
expect block destructive-rm-guard.sh "rm -rf * (wildcard)" "$(bash_cmd 'rm -rf *')"
expect block destructive-rm-guard.sh "absolute path outside project" "$(bash_cmd 'rm -rf /etc/nginx')"
expect allow destructive-rm-guard.sh "node_modules in repo" "$(bash_cmd 'rm -rf node_modules')"
expect allow destructive-rm-guard.sh "./dist"              "$(bash_cmd 'rm -rf ./dist')"
expect allow destructive-rm-guard.sh "absolute path inside project" "$(bash_cmd "rm -rf $PWD/dist")"
expect allow destructive-rm-guard.sh "scratch under /tmp"  "$(bash_cmd 'rm -rf /tmp/scratch-123')"
expect allow destructive-rm-guard.sh "non-recursive rm"    "$(bash_cmd 'rm file.txt')"
expect allow destructive-rm-guard.sh "echo mentions rm -rf /" "$(bash_cmd 'echo "rm -rf /"')"

# --- conventional-commit-check ---------------------------------------------
expect allow conventional-commit-check.sh "valid feat"     "$(bash_cmd 'git commit -m "feat(auth): add reset"')"
expect allow conventional-commit-check.sh "valid chore"    "$(bash_cmd 'git commit -m "chore(plugin): bump"')"
expect block conventional-commit-check.sh "no type prefix" "$(bash_cmd 'git commit -m "added stuff"')"
expect block conventional-commit-check.sh "unknown type"   "$(bash_cmd 'git commit -m "feature: add x"')"
expect block conventional-commit-check.sh "subject > 72"   "$(bash_cmd "git commit -m \"feat: $(printf 'x%.0s' {1..80})\"")"
expect allow conventional-commit-check.sh "not a commit"   "$(bash_cmd 'git log -1')"
expect allow conventional-commit-check.sh "-am valid"      "$(bash_cmd 'git commit -am "fix: y"')"
expect block conventional-commit-check.sh "-am invalid"    "$(bash_cmd 'git commit -am "wip"')"
expect allow conventional-commit-check.sh "heredoc valid (Claude Code form)" "$(bash_cmd "$(heredoc_commit 'feat(hooks): accept heredoc')")"
expect block conventional-commit-check.sh "heredoc invalid" "$(bash_cmd "$(heredoc_commit 'added stuff')")"
expect allow conventional-commit-check.sh "message from variable" "$(bash_cmd 'git commit -m "$MSG"')"

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

# --- layer-autoload --------------------------------------------------------
# expect_layers <description> <project-dir> <session> <relative-file> <heading|NONE>
# Asserts the injected context contains "### <heading> (" (or nothing for NONE).
expect_layers() {
  local desc="$1" proj="$2" sess="$3" file="$4" want="$5" ctx ok=0
  ctx=$(jq -nc --arg f "$proj/$file" --arg d "$proj" --arg s "$sess" \
          '{tool_input:{file_path:$f}, cwd:$d, session_id:$s}' \
        | bash "$HOOKS/layer-autoload.sh" 2>/dev/null \
        | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  if [ "$want" = "NONE" ]; then [ -z "$ctx" ] && ok=1
  else printf '%s' "$ctx" | grep -qF "### $want (" && ok=1
  fi
  if [ $ok -eq 1 ]; then PASS=$((PASS + 1)); echo "ok    layer-autoload.sh: $desc"
  else
    FAIL=$((FAIL + 1)); echo "FAIL  layer-autoload.sh: $desc (wanted $want; got: $(printf '%s' "$ctx" | grep '^### ' | tr '\n' ' '))"
    [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "::error file=$HOOKS/layer_autoload.py::$desc"
  fi
}
not_layer() {  # not_layer <description> <project-dir> <session> <relative-file> <heading>
  local ctx
  ctx=$(jq -nc --arg f "$2/$4" --arg d "$2" --arg s "$3" '{tool_input:{file_path:$f}, cwd:$d, session_id:$s}' \
        | bash "$HOOKS/layer-autoload.sh" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
  if printf '%s' "$ctx" | grep -qF "### $5 ("; then
    FAIL=$((FAIL + 1)); echo "FAIL  layer-autoload.sh: $1 ($5 should not load)"
  else PASS=$((PASS + 1)); echo "ok    layer-autoload.sh: $1"; fi
}
sid() { echo "ci-$RANDOM$RANDOM$RANDOM"; }

REACT="$TMP/react-app"; mkdir -p "$REACT"
echo '{"dependencies":{"react":"19","zod":"3","@mui/material":"6","@prisma/client":"5"}}' > "$REACT/package.json"
expect_layers "React component gets react-standards" "$REACT" "$(sid)" src/components/Button.tsx react-standards
not_layer     "Vue layer skipped in a React app (package.json)" "$REACT" "$(sid)" src/components/Button.tsx vue
expect_layers "zod schema gets zod-validation" "$REACT" "$(sid)" src/schemas/user.schema.ts zod-validation
not_layer     "mongodb skipped without mongoose/mongodb dep" "$REACT" "$(sid)" src/schemas/user.schema.ts mongodb
expect_layers "prisma schema gets database-sql" "$REACT" "$(sid)" prisma/schema.prisma database-sql
expect_layers "unrelated file loads nothing" "$REACT" "$(sid)" notes/todo.txt NONE
expect_layers "outside the project loads nothing" "$REACT" "$(sid)" ../elsewhere/App.tsx NONE

S=$(sid)
expect_layers "first touch in a session injects" "$REACT" "$S" src/components/Card.tsx react-standards
expect_layers "same layer is not re-injected in that session" "$REACT" "$S" src/components/Modal.tsx NONE

PY="$TMP/py-app"; mkdir -p "$PY"; echo "django" > "$PY/requirements.txt"
expect_layers "Django model gets python-django" "$PY" "$(sid)" app/models.py python-django
not_layer     "nextjs skipped in a Python project" "$PY" "$(sid)" app/models.py nextjs

SJ="$TMP/stackjson-app"; mkdir -p "$SJ"; echo '{"frontend":"vue"}' > "$SJ/stack.json"
expect_layers "stack.json frontend=vue loads vue" "$SJ" "$(sid)" src/components/Button.vue vue
not_layer     "stack.json frontend=vue skips react-standards" "$SJ" "$(sid)" src/components/Button.tsx react-standards

CAP=$(jq -nc --arg f "$REACT/src/components/Big.tsx" --arg d "$REACT" --arg s "$(sid)" '{tool_input:{file_path:$f},cwd:$d,session_id:$s}' \
      | bash "$HOOKS/layer-autoload.sh" | jq -r '.hookSpecificOutput.additionalContext' | grep -c '^### ')
if [ "$CAP" -le 3 ]; then PASS=$((PASS + 1)); echo "ok    layer-autoload.sh: at most 3 layers per call ($CAP)"
else FAIL=$((FAIL + 1)); echo "FAIL  layer-autoload.sh: injected $CAP layers (cap is 3)"; fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
