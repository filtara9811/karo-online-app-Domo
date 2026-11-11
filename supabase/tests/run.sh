#!/usr/bin/env bash
# Local Postgres par v3 migration + security tests.
# Zaroorat: postgres server chal raha ho (CI me service container), psql.
#   PGHOST/PGUSER/PGPASSWORD env se.  Database "karo_test" har baar naya banta hai.
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${KARO_TEST_DB:-karo_test}
psql -q -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f tests/supabase_stub.sql
for f in migrations/*.sql; do
  echo "→ $f"
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"
done
# migrations dobara chalein to bhi theek (idempotent)
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f migrations/20261111000000_karo_v3_secure.sql 2>/dev/null
psql -v ON_ERROR_STOP=1 -d "$DB" -f tests/karo_v3_test.sql
