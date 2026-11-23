#!/bin/sh
set -eu
container=tagbible-maintenance-test
[ "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$container")" = none ] || { echo 'Refusing a non-isolated test container' >&2; exit 1; }
# Dedicated disposable container only. Never accepts a production connection URL.
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < tests/maintenance-seed.sql
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < cloud/schema.sql
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < cloud/groups.sql
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < tests/maintenance-fixture.sql
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < cloud/maintenance/2026-11-23-launch-preparation.sql
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < tests/maintenance-assert.sql
repeat_log=$(mktemp)
if docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < cloud/maintenance/2026-11-23-launch-preparation.sql > "$repeat_log" 2>&1; then
 echo 'ERROR: repeated cleanup unexpectedly accepted' >&2; exit 1
fi
rg -q 'Counts changed; nothing cleared' "$repeat_log"
rm "$repeat_log"
echo 'PASS: cleanup/admin restrictions/private backup/preserved data/retries/count guard'
