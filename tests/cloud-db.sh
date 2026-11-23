#!/bin/sh
set -eu
container="eyebible-cloud-test"
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
drop schema public cascade; create schema public; grant usage on schema public to public;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key);
insert into auth.users values ('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002') on conflict do nothing;
do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if; if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if; end $$;
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
SQL
if [ -f cloud/schema.sql ]; then docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < cloud/schema.sql; fi
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < tests/cloud-db.sql
