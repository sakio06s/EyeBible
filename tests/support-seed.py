from pathlib import Path
import subprocess
actor='99999999-0000-4000-8000-000000000009'
def sql(query):return subprocess.run(['docker','exec','-i','eyebible-cloud-test','psql','-U','postgres','-At','-v','ON_ERROR_STOP=1'],input=query,text=True,capture_output=True)
setup=f"""alter table auth.users add column if not exists email_confirmed_at timestamptz;
create table if not exists auth.identities(user_id uuid references auth.users(id) on delete cascade,provider text,identity_data jsonb,primary key(user_id,provider));
insert into auth.users(id,email,email_confirmed_at) values('{actor}','unconfirmed@example.test',null) on conflict(id) do update set email=excluded.email,email_confirmed_at=null;
insert into auth.identities values('{actor}','google','{{"email":"unconfirmed@example.test","email_verified":true}}') on conflict(user_id,provider) do update set identity_data=excluded.identity_data;
"""
assert sql(setup).returncode==0
source=Path('cloud/upgrade-support.sql').read_text()
try:
 bad=source.replace('__ADMIN_LOGIN_EMAIL__','unconfirmed@example.test').replace('begin;','begin;create table public._support_rollback_probe(id int);',1)
 result=sql(bad)
 assert result.returncode!=0,'Unconfirmed account must not become administrator'
 assert sql("select to_regclass('public._support_rollback_probe') is null;").stdout.strip()=='t','Failed seed must roll back all DDL'
 assert sql(f"select count(*) from public.eyebible_app_admins where user_id='{actor}';").stdout.strip()=='0'
 assert sql(f"update auth.users set email_confirmed_at=clock_timestamp() where id='{actor}';delete from auth.identities where user_id='{actor}';").returncode==0
 result=sql(source.replace('__ADMIN_LOGIN_EMAIL__','unconfirmed@example.test'))
 assert result.returncode!=0,'Verified address without Google identity must not satisfy Google-only admin seed'
 print('PASS admin seed: unconfirmed and non-Google identities rejected, migration DDL rollback verified')
finally:sql(f"drop table if exists public._support_rollback_probe;delete from public.eyebible_app_admins where user_id='{actor}';delete from auth.users where id='{actor}';")
