#!/usr/bin/env bash
# Warns when a migration file declares an `up` but no `down`/rollback path.
# Covers Knex / TypeORM / Sequelize / plain SQL up.sql + down.sql conventions.
# Informational only — never blocks (Prisma-style migrations have no down by design).

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)

[ -z "$CONTENT" ] && exit 0

# Only inspect files clearly in a migrations directory
case "$FILE" in
  */migrations/*|*/migrate/*|*/db/migrate/*|*/prisma/migrations/*) ;;
  *) exit 0 ;;
esac

# Prisma: only emits migration.sql with up SQL only — accepted convention, skip
case "$FILE" in
  */prisma/migrations/*/migration.sql) exit 0 ;;
esac

WARN=""

# Knex / TypeORM / Sequelize style: same file should contain both up and down
HAS_UP=$(echo "$CONTENT" | grep -cE '\b(exports\.up|public[[:space:]]+async[[:space:]]+up|async[[:space:]]+up|^[[:space:]]*up[[:space:]]*[:=]|def[[:space:]]+upgrade)\b')
HAS_DOWN=$(echo "$CONTENT" | grep -cE '\b(exports\.down|public[[:space:]]+async[[:space:]]+down|async[[:space:]]+down|^[[:space:]]*down[[:space:]]*[:=]|def[[:space:]]+downgrade)\b')

if [ "$HAS_UP" -gt 0 ] && [ "$HAS_DOWN" -eq 0 ]; then
  WARN="migration $FILE declares an 'up'/'upgrade' path but no 'down'/'downgrade' — add a rollback or document why it's irreversible."
fi

# Plain SQL: if path ends with .up.sql, expect a sibling .down.sql
case "$FILE" in
  *.up.sql)
    DOWN="${FILE%.up.sql}.down.sql"
    [ -f "$DOWN" ] || WARN="migration $FILE has no sibling $(basename "$DOWN") — add a rollback file."
    ;;
esac

if [ -n "$WARN" ]; then
  echo "🟡 migration-down-required: $WARN"
fi

exit 0
