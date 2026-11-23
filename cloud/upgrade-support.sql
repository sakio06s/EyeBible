-- Existing EyeBible project upgrade. Replace the final admin-email placeholder before Run.
-- Adds support data and changes activity ordering; existing messages/notes/members remain.
begin;
create index if not exists eyebible_posts_latest_activity on public.eyebible_posts(group_id,(greatest(last_reply_at,created_at)) desc,id desc) where deleted_at is null;
create or replace function public.eyebible_post_payload(p_id uuid,p_group uuid,p_actor uuid)
returns jsonb language sql stable set search_path=pg_catalog,public as $$
 select jsonb_build_object('id',pp.id,'authorId',pp.author_id,'name',coalesce(mm.name,pp.author->>'name','已離開的成員'),'avatar',coalesce(mm.avatar,pp.author->>'avatar','🌿'),'image','','text',pp.text,'reference',pp.reference,'quote',pp.quote,'reading',pp.reading,'verse',pp.verse,'createdAt',pp.created_at,'date',(pp.created_at at time zone 'Asia/Taipei')::date,'lastActivity',greatest(pp.last_reply_at,pp.created_at),'hasReplies',pp.last_reply_at is not null,
 'likes',(select count(*) from public.eyebible_reactions where post_id=pp.id),'liked',exists(select 1 from public.eyebible_reactions where post_id=pp.id and user_id=p_actor),
 'replyCount',(select count(*) from public.eyebible_replies where post_id=pp.id and deleted_at is null),
 'replies',coalesce((select jsonb_agg(to_jsonb(r) order by r."createdAt",r.id) from (
  select rr.id,rr.author_id as "authorId",coalesce(rm.name,rr.author->>'name') as name,coalesce(rm.avatar,rr.author->>'avatar') as avatar,''::text as image,rr.text,rr.created_at as "createdAt",(select count(*) from public.eyebible_reply_reactions where reply_id=rr.id) as likes,exists(select 1 from public.eyebible_reply_reactions where reply_id=rr.id and user_id=p_actor) as liked
  from public.eyebible_replies rr left join public.eyebible_members rm on rm.user_id=rr.author_id and rm.group_id=p_group where rr.post_id=pp.id and rr.deleted_at is null order by rr.created_at,rr.id limit 100
 )r),'[]'::jsonb),
 'unseen',coalesce((select jsonb_agg(activity) from (
  select 'post:'||pp.id::text as activity where not exists(select 1 from public.eyebible_seen where group_id=p_group and user_id=p_actor and activity='post:'||pp.id::text)
  union all select 'reply:'||rr.id::text from (select id from public.eyebible_replies where post_id=pp.id and deleted_at is null order by created_at,id limit 100)rr where not exists(select 1 from public.eyebible_seen where group_id=p_group and user_id=p_actor and activity='reply:'||rr.id::text)
 )s),'[]'::jsonb))
 from public.eyebible_posts pp left join public.eyebible_members mm on mm.user_id=pp.author_id and mm.group_id=p_group where pp.id=p_id and pp.group_id=p_group and pp.deleted_at is null;
$$;
revoke all on function public.eyebible_post_payload(uuid,uuid,uuid) from public,anon,authenticated;

create or replace function public.group_feed(p_cursor jsonb default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid();overview jsonb;gid uuid;rows jsonb;extra boolean;cursor_time timestamptz;cursor_id uuid;next_cursor jsonb;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501';end if;
 overview:=public.group_read('overview');
 if overview->'group'='null'::jsonb then return overview||jsonb_build_object('next',null);end if;
 gid:=(overview->'group'->>'id')::uuid;
 if p_cursor is not null and p_cursor<>'null'::jsonb then
  if jsonb_typeof(p_cursor)<>'object' or octet_length(p_cursor::text)>1024 or jsonb_typeof(p_cursor->'replied') is distinct from 'boolean' then raise exception 'Invalid wall cursor' using errcode='22023';end if;
  begin cursor_time:=(p_cursor->>'time')::timestamptz;cursor_id:=(p_cursor->>'id')::uuid;exception when others then raise exception 'Invalid wall cursor' using errcode='22023';end;
  if cursor_time is null or cursor_id is null then raise exception 'Invalid wall cursor' using errcode='22023';end if;
 end if;
 select coalesce(jsonb_agg(public.eyebible_post_payload(q.id,gid,actor) order by q.activity desc,q.id desc),'[]'::jsonb) into rows from (
  select pp.id,greatest(pp.last_reply_at,pp.created_at) as activity from public.eyebible_posts pp where pp.group_id=gid and pp.deleted_at is null
   and (cursor_time is null or (greatest(pp.last_reply_at,pp.created_at),pp.id)<(cursor_time,cursor_id))
  order by greatest(pp.last_reply_at,pp.created_at) desc,pp.id desc limit 11
 )q;
 extra:=jsonb_array_length(rows)>10;if extra then rows:=rows-10;next_cursor:=jsonb_build_object('time',rows->9->>'lastActivity','id',rows->9->>'id','replied',rows->9->'hasReplies');end if;
 return overview||jsonb_build_object('posts',rows,'next',next_cursor,'sortVersion',2);
end $$;
revoke all on function public.group_feed(jsonb) from public,anon;
grant execute on function public.group_feed(jsonb) to authenticated;

create table if not exists public.eyebible_app_admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists public.eyebible_feedback(
 id uuid primary key,provided_by uuid references auth.users(id) on delete set null,sender_name text not null check(length(sender_name) between 1 and 60),message text not null check(length(message) between 1 and 2000),
 created_at timestamptz not null default clock_timestamp(),resolved_at timestamptz,deleted_at timestamptz
);
create index if not exists eyebible_feedback_recent on public.eyebible_feedback(created_at desc,id desc) where deleted_at is null;
create index if not exists eyebible_feedback_sender on public.eyebible_feedback(provided_by,created_at);
create table if not exists public.eyebible_feedback_reads(admin_id uuid references public.eyebible_app_admins(user_id) on delete cascade,report_id uuid references public.eyebible_feedback(id) on delete cascade,seen_at timestamptz not null default clock_timestamp(),primary key(admin_id,report_id));
alter table public.eyebible_app_admins enable row level security;
alter table public.eyebible_feedback enable row level security;
alter table public.eyebible_feedback_reads enable row level security;
revoke all on public.eyebible_app_admins,public.eyebible_feedback,public.eyebible_feedback_reads from public,anon,authenticated;
create or replace function public.eyebible_is_app_admin(actor uuid) returns boolean language sql stable security definer set search_path=pg_catalog,public as $$ select actor is not null and exists(select 1 from public.eyebible_app_admins where user_id=actor);$$;
create or replace function public.eyebible_feedback_unread(actor uuid) returns integer language sql stable set search_path=pg_catalog,public as $$ select count(*)::integer from public.eyebible_feedback f where f.deleted_at is null and not exists(select 1 from public.eyebible_feedback_reads r where r.admin_id=actor and r.report_id=f.id);$$;
create or replace function public.eyebible_feedback_payload(target uuid) returns jsonb language sql stable set search_path=pg_catalog,public as $$ select jsonb_build_object('id',id,'authorId',provided_by,'name',sender_name,'text',message,'createdAt',created_at,'resolvedAt',resolved_at) from public.eyebible_feedback where id=target and deleted_at is null;$$;
revoke all on function public.eyebible_is_app_admin(uuid),public.eyebible_feedback_unread(uuid),public.eyebible_feedback_payload(uuid) from public,anon,authenticated;
create or replace function public.feedback_read(p_mode text default 'overview',p_before_time timestamptz default null,p_before_id uuid default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid();rows jsonb:='[]';next_cursor jsonb;item jsonb;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501';end if;
 if not public.eyebible_is_app_admin(actor) then return jsonb_build_object('is_admin',false,'unread',0,'reports','[]'::jsonb,'next',null);end if;
 if p_mode not in ('overview','list') then raise exception 'Invalid support mode' using errcode='22023';end if;
 if p_mode='list' then
  select coalesce(jsonb_agg(public.eyebible_feedback_payload(q.id) order by q.created_at desc,q.id desc),'[]') into rows from (
   select f.id,f.created_at from public.eyebible_feedback f where f.deleted_at is null and (p_before_time is null or (f.created_at,f.id)<(p_before_time,coalesce(p_before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))) order by f.created_at desc,f.id desc limit 21
  )q;
  if jsonb_array_length(rows)>20 then rows:=rows-20;next_cursor:=jsonb_build_object('time',rows->19->>'createdAt','id',rows->19->>'id');end if;
  for item in select value from jsonb_array_elements(rows) loop insert into public.eyebible_feedback_reads(admin_id,report_id) values(actor,(item->>'id')::uuid) on conflict do nothing;end loop;
 end if;
 return jsonb_build_object('is_admin',true,'unread',public.eyebible_feedback_unread(actor),'reports',rows,'next',next_cursor);
end $$;
create or replace function public.feedback_action(p_action text,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid();target uuid;report public.eyebible_feedback;body text;sender text;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>20000 or jsonb_typeof(p_data->'id') is distinct from 'string' then raise exception 'Invalid report' using errcode='22023';end if;
 begin target:=(p_data->>'id')::uuid;exception when others then raise exception 'Invalid report id' using errcode='22023';end;
 if p_action='submit' then
  if jsonb_typeof(p_data->'text') is distinct from 'string' then raise exception 'Invalid report text' using errcode='22023';end if;
  body:=trim(p_data->>'text');if length(body) not between 1 and 2000 then raise exception 'Invalid report length' using errcode='22023';end if;
  perform pg_advisory_xact_lock(hashtextextended('eyebible-feedback:'||actor::text,0));
  select * into report from public.eyebible_feedback where id=target;
  if found then
   if report.provided_by is distinct from actor then raise exception 'Report belongs to another user' using errcode='42501';end if;
   if report.message<>body then raise exception 'Report id already used' using errcode='22023';end if;
   return jsonb_build_object('ok',true);
  end if;
  if (select count(*) from public.eyebible_feedback where provided_by=actor and created_at>=clock_timestamp()-interval '10 minutes')>=5 then raise exception 'feedback_rate_limit';end if;
  sender:=left(regexp_replace(trim(coalesce(p_data->>'name','組員')),E'[\r\n\u2028\u2029]+',' ','g'),60);if sender='' then sender:='組員';end if;
  insert into public.eyebible_feedback(id,provided_by,sender_name,message) values(target,actor,sender,body);
  return jsonb_build_object('ok',true);
 end if;
 if not public.eyebible_is_app_admin(actor) then raise exception 'Administrator required' using errcode='42501';end if;
 select * into report from public.eyebible_feedback where id=target for update;if not found then raise exception 'Report unavailable' using errcode='42501';end if;
 if p_action='delete' then update public.eyebible_feedback set deleted_at=coalesce(deleted_at,clock_timestamp()) where id=target;
 elsif p_action='resolve' and report.deleted_at is null then update public.eyebible_feedback set resolved_at=coalesce(resolved_at,clock_timestamp()) where id=target;
 else raise exception 'Invalid support action' using errcode='22023';end if;
 insert into public.eyebible_feedback_reads(admin_id,report_id) values(actor,target) on conflict do nothing;
 return jsonb_build_object('ok',true,'unread',public.eyebible_feedback_unread(actor),'deleted_id',case when p_action='delete' then target else null end,'report',public.eyebible_feedback_payload(target));
end $$;
revoke all on function public.feedback_read(text,timestamptz,uuid),public.feedback_action(text,jsonb) from public,anon;
grant execute on function public.feedback_read(text,timestamptz,uuid),public.feedback_action(text,jsonb) to authenticated;
-- This value is used only here in the SQL editor, never returned to the browser.
do $$ declare admin_id uuid;begin
 select u.id into admin_id from auth.users u where lower(u.email)=lower('__ADMIN_LOGIN_EMAIL__') and u.email_confirmed_at is not null and exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google' and lower(i.identity_data->>'email')=lower(u.email) and i.identity_data->>'email_verified'='true') limit 1;
 if admin_id is null then raise exception 'Replace admin email and sign into EyeBible with that verified Google account before running this upgrade' using errcode='22023';end if;
 insert into public.eyebible_app_admins(user_id) values(admin_id) on conflict do nothing;
end $$;
commit;
notify pgrst,'reload schema';
