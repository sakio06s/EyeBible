-- One-time, count-checked cleanup authorized for 13 posts / 4 replies / 3+1 Amens
-- and 14 non-private personal note/share copies. Close the app while running.
-- Original public content is backed up privately; tombstone IDs prevent retry revival.
begin;
lock table public.eyebible_posts, public.eyebible_replies,
 public.eyebible_reactions, public.eyebible_reply_reactions,
 public.eyebible_seen, public.personal_states in share row exclusive mode;
do $counts$
declare actual bigint[];
begin
 select array[
  (select count(*) from public.eyebible_posts),
  (select count(*) from public.eyebible_replies),
  (select count(*) from public.eyebible_reactions),
  (select count(*) from public.eyebible_reply_reactions),
  (select count(*) from public.personal_states s,
   lateral jsonb_each(s.payload->'records') r
   where r.key like '["note",%' and r.value->'private' is distinct from 'true'::jsonb)
 ] into actual;
 if actual is distinct from array[13,4,3,1,14]::bigint[] then
  raise exception 'Counts changed; nothing cleared. Expected [13,4,3,1,14], found %',actual;
 end if;
end $counts$;
create schema if not exists tagbible_maintenance_private;
revoke all on schema tagbible_maintenance_private from public,anon,authenticated;
create table if not exists tagbible_maintenance_private.discussion_backup(
 id bigint generated always as identity primary key,
 run_id uuid not null,category text not null,row_data jsonb not null,
 created_at timestamptz not null default clock_timestamp()
);
alter table tagbible_maintenance_private.discussion_backup enable row level security;
revoke all on tagbible_maintenance_private.discussion_backup from public,anon,authenticated;
revoke all on all sequences in schema tagbible_maintenance_private from public,anon,authenticated;
create temporary table discussion_cleanup_run on commit drop as select gen_random_uuid() as id;
create temporary table discussion_cleanup_personal on commit drop as
 select s.user_id,s.revision,jsonb_object_agg(r.key,r.value) as removed
 from public.personal_states s cross join lateral jsonb_each(s.payload->'records') r
 where (r.key like '["note",%' and r.value->'private' is distinct from 'true'::jsonb)
    or r.key like '["reply",%' or r.key like '["likes",%' or r.key like '["seenActivity",%'
 group by s.user_id,s.revision;
insert into tagbible_maintenance_private.discussion_backup(run_id,category,row_data)
 select r.id,'posts',to_jsonb(p) from public.eyebible_posts p cross join discussion_cleanup_run r
 union all select r.id,'replies',to_jsonb(p) from public.eyebible_replies p cross join discussion_cleanup_run r
 union all select r.id,'post_amens',to_jsonb(p) from public.eyebible_reactions p cross join discussion_cleanup_run r
 union all select r.id,'reply_amens',to_jsonb(p) from public.eyebible_reply_reactions p cross join discussion_cleanup_run r
 union all select r.id,'seen',to_jsonb(p) from public.eyebible_seen p cross join discussion_cleanup_run r
 union all select r.id,'personal_public_records',jsonb_build_object('user_id',p.user_id,'revision_before',p.revision,'records',p.removed)
 from discussion_cleanup_personal p cross join discussion_cleanup_run r;
-- Keep IDs/ownership as tombstones so delayed retries cannot recreate cleared posts.
update public.eyebible_replies set deleted_at=coalesce(deleted_at,clock_timestamp()),
 text='[已清除]',author='{}'::jsonb;
update public.eyebible_posts set deleted_at=coalesce(deleted_at,clock_timestamp()),
 text='[已清除]',author='{}'::jsonb,reference='',quote='',reading=null,verse=null,last_reply_at=null;
delete from public.eyebible_reply_reactions;
delete from public.eyebible_reactions;
delete from public.eyebible_seen;
-- Revision bump forces existing devices to merge the server-side removals.
update public.personal_states s
 set payload=jsonb_set(s.payload,'{records}',(s.payload->'records')-array(select jsonb_object_keys(c.removed))),
     revision=s.revision+1,updated_at=clock_timestamp()
 from discussion_cleanup_personal c where c.user_id=s.user_id;
select (select id from discussion_cleanup_run) as private_backup_run,
 (select count(*) from public.eyebible_posts where deleted_at is null) as visible_posts,
 (select count(*) from public.eyebible_replies where deleted_at is null) as visible_replies,
 (select count(*) from public.eyebible_reactions) as post_amens,
 (select count(*) from public.eyebible_reply_reactions) as reply_amens,
 (select count(*) from public.personal_states s,lateral jsonb_each(s.payload->'records') r
  where r.key like '["note",%' and r.value->'private' is distinct from 'true'::jsonb) as public_history_copies;
commit;
