#!/usr/bin/env bash
# Runs the SQL suite against a plain Postgres (>= 15) using the Supabase shim.
# Usage: PGHOST=... PGPORT=... PGUSER=postgres ./run-plain.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${TEST_DB:-speaking_test}"
dropdb --if-exists "$DB" >/dev/null
createdb "$DB"
run() { psql -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run -f tests/shim/supabase_shim.sql
export PGOPTIONS='-c client_min_messages=warning'
for f in migrations/*.sql; do run -f "$f"; done
run -f seed/exam_catalog.sql
run -f tests/helpers.sql
failed=0
# Shared fixtures (the Dart tests read the same files): 07_session_control.sql.
FIX=../../../content/fixtures
for t in tests/sql/*.sql; do
  if out=$(run -v golden="$(cat "$FIX/control-golden.json")" -v timeline="$(cat "$FIX/timeline-golden.json")" -f "$t" 2>&1); then echo "ok   $(basename "$t")"; else echo "FAIL $(basename "$t")"; echo "$out" | sed 's/^/     /'; failed=1; fi
done
dropdb "$DB"
exit $failed
