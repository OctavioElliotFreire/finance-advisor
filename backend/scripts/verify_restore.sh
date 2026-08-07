#!/usr/bin/env bash
# Verifies a Postgres dump/restore round-trip actually works: dumps a source
# database, restores it into a fresh throwaway database, and compares row
# counts table-by-table. See PLAN.md's Milestone 10 "Restore tests" note.
#
# Defaults to the local Docker Postgres container/db used by the backend
# test suite (see CLAUDE.md's Known test surfaces). To point this at a real
# Supabase project instead, set SOURCE_DATABASE_URL to the project's Session
# Pooler connection string (IPv4) -- Supabase's direct db.<ref>.supabase.co
# host is IPv6-only and unreachable from networks without an IPv6 route.
#
# Usage: MSYS_NO_PATHCONV=1 bash backend/scripts/verify_restore.sh
set -euo pipefail

CONTAINER="${DB_CONTAINER:-finance-advisor-db-1}"
DB_USER="${DB_USER:-finance_app}"
SOURCE_DB="${SOURCE_DB:-family_finance}"
RESTORE_DB="${RESTORE_DB:-family_finance_restore_check}"
DUMP_PATH="/tmp/restore_check_dump.sql"

export MSYS_NO_PATHCONV=1

if [ -n "${SOURCE_DATABASE_URL:-}" ]; then
  echo "==> Dumping source via SOURCE_DATABASE_URL"
  docker exec "$CONTAINER" pg_dump "$SOURCE_DATABASE_URL" -f "$DUMP_PATH"
  COUNT_SOURCE=(docker exec "$CONTAINER" psql "$SOURCE_DATABASE_URL" -Atc)
else
  echo "==> Dumping local $SOURCE_DB from container $CONTAINER"
  docker exec "$CONTAINER" pg_dump -U "$DB_USER" -d "$SOURCE_DB" -f "$DUMP_PATH"
  COUNT_SOURCE=(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$SOURCE_DB" -Atc)
fi

echo "==> Dropping any stale $RESTORE_DB and recreating"
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $RESTORE_DB;"
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $RESTORE_DB OWNER $DB_USER;"

echo "==> Restoring dump into $RESTORE_DB"
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$RESTORE_DB" -v ON_ERROR_STOP=1 -f "$DUMP_PATH"

echo "==> Comparing row counts, table by table"
TABLES=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$RESTORE_DB" -Atc \
  "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;")

FAILED=0
for t in $TABLES; do
  SRC_COUNT=$("${COUNT_SOURCE[@]}" "SELECT COUNT(*) FROM \"$t\";")
  DST_COUNT=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$RESTORE_DB" -Atc "SELECT COUNT(*) FROM \"$t\";")
  if [ "$SRC_COUNT" != "$DST_COUNT" ]; then
    echo "MISMATCH: $t source=$SRC_COUNT restored=$DST_COUNT"
    FAILED=1
  else
    echo "OK: $t ($SRC_COUNT rows)"
  fi
done

echo "==> Cleaning up"
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $RESTORE_DB;"
docker exec "$CONTAINER" rm -f "$DUMP_PATH"

if [ "$FAILED" -ne 0 ]; then
  echo "RESTORE VERIFICATION FAILED"
  exit 1
fi
echo "RESTORE VERIFICATION PASSED"
