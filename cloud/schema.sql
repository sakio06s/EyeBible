-- Run once in the Supabase SQL editor. Safe to re-run; no existing records are deleted.
begin;
create table if not exists public.personal_states (
 user_id uuid primary key references auth.users(id) on delete cascade,
 revision bigint not null check(revision>0),
 payload jsonb not null check(jsonb_typeof(payload)='object'),
 updated_at timestamptz not null default now()
);
alter table public.personal_states enable row level security;
revoke all on public.personal_states from public,anon,authenticated;
grant select on public.personal_states to authenticated;
drop policy if exists personal_states_owner_read on public.personal_states;
create policy personal_states_owner_read on public.personal_states for select to authenticated using(user_id=(select auth.uid()));

create or replace function public.save_personal_state(p_expected_revision bigint,p_payload jsonb)
returns bigint language plpgsql security definer set search_path=pg_catalog,public as $$
declare owner_id uuid:=auth.uid(); next_revision bigint;
begin
 if owner_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_expected_revision is null or p_expected_revision<0 then raise exception 'Invalid revision' using errcode='22023'; end if;
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or (p_payload->'schemaVersion') is distinct from '1'::jsonb or jsonb_typeof(p_payload->'records') is distinct from 'object' or octet_length(p_payload::text)>8388608 then
  raise exception 'Invalid state payload' using errcode='22023';
 end if;
 if p_expected_revision=0 then
  insert into public.personal_states(user_id,revision,payload) values(owner_id,1,p_payload)
  on conflict(user_id) do nothing returning revision into next_revision;
 else
  update public.personal_states set revision=revision+1,payload=p_payload,updated_at=now()
  where user_id=owner_id and revision=p_expected_revision returning revision into next_revision;
 end if;
 if next_revision is null then raise exception 'Cloud revision changed' using errcode='40001'; end if;
 return next_revision;
end;
$$;
revoke all on function public.save_personal_state(bigint,jsonb) from public,anon;
grant execute on function public.save_personal_state(bigint,jsonb) to authenticated;
commit;
