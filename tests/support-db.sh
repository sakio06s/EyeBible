#!/bin/sh
set -eu
docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
alter table auth.users add column if not exists email text;
alter table auth.users add column if not exists email_confirmed_at timestamptz;
create table if not exists auth.identities(user_id uuid references auth.users(id) on delete cascade,provider text,identity_data jsonb,primary key(user_id,provider));
update auth.users set email_confirmed_at=clock_timestamp(),email='admin@example.test' where id='00000000-0000-0000-0000-000000000001';
insert into auth.identities values('00000000-0000-0000-0000-000000000001','google','{"email":"admin@example.test","email_verified":true}') on conflict(user_id,provider) do update set identity_data=excluded.identity_data;
SQL
python3 -c "from pathlib import Path; print(Path('cloud/upgrade-support.sql').read_text().replace('__ADMIN_LOGIN_EMAIL__','admin@example.test'))" | docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1
docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < tests/support-db.sql
python3 tests/support-races.py
python3 tests/support-seed.py
docker exec -i eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 < tests/activity-index.sql
