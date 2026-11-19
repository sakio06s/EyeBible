#!/bin/sh
set -eu
sh tests/cloud-db.sh
if [ -f cloud/groups.sql ]; then docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < cloud/groups.sql; fi
docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < tests/groups-db.sql
docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < tests/groups-payload.sql
sh tests/groups-races.sh

docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < tests/feed-ten.sql
