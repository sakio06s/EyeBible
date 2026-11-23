drop schema public cascade; create schema public; grant usage on schema public to public;
drop schema if exists auth cascade;
drop schema if exists tagbible_maintenance_private cascade;
create schema if not exists auth;
create table auth.users(id uuid primary key);
insert into auth.users select ('00000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid from generate_series(1,5)n;
do $$begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin;end if;if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin;end if;end $$;
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema auth to authenticated;
