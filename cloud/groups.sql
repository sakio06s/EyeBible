-- Additive migration. Re-runnable; does not expose or delete personal_states.
begin;
create table if not exists public.eyebible_groups(
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 60),
 owner_id uuid not null references auth.users(id),
 invite_code text unique not null default replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),
 invite_expires_at timestamptz not null default now()+interval '30 days',created_at timestamptz not null default now()
);
create table if not exists public.eyebible_members(
 user_id uuid primary key references auth.users(id) on delete cascade,group_id uuid not null references public.eyebible_groups(id),
 name text not null check(length(name) between 1 and 20),avatar text not null default '🌿' check(length(avatar)<=32),
 image text not null default '' check(octet_length(image)<=400000 and (image='' or image ~ '^data:image/(png|jpeg|webp);base64,')),joined_at timestamptz not null default now()
);
create index if not exists eyebible_members_group on public.eyebible_members(group_id);
create table if not exists public.eyebible_blocks(group_id uuid not null references public.eyebible_groups(id),user_id uuid not null references auth.users(id) on delete cascade,name text not null,primary key(group_id,user_id));
create table if not exists public.eyebible_posts(
 id uuid primary key,group_id uuid not null references public.eyebible_groups(id),author_id uuid references auth.users(id) on delete set null,
 author jsonb not null,text text not null check(length(text) between 1 and 10000),reference text not null default '' check(length(reference)<=200),quote text not null default '' check(length(quote)<=20000),
 reading jsonb,verse integer check(verse>0),created_at timestamptz not null default clock_timestamp(),deleted_at timestamptz,
 check(reading is null or (jsonb_typeof(reading)='object' and octet_length(reading::text)<=200000))
);
create index if not exists eyebible_posts_feed on public.eyebible_posts(group_id,created_at desc,id desc) where deleted_at is null;
create table if not exists public.eyebible_replies(
 id uuid primary key,post_id uuid not null references public.eyebible_posts(id),author_id uuid references auth.users(id) on delete set null,
 author jsonb not null,text text not null check(length(text) between 1 and 2000),created_at timestamptz not null default clock_timestamp(),deleted_at timestamptz
);
create index if not exists eyebible_replies_post on public.eyebible_replies(post_id,created_at,id);
create table if not exists public.eyebible_reactions(post_id uuid not null references public.eyebible_posts(id),user_id uuid not null references auth.users(id) on delete cascade,primary key(post_id,user_id));
create table if not exists public.eyebible_completions(group_id uuid not null references public.eyebible_groups(id),user_id uuid not null references auth.users(id) on delete cascade,date date not null,primary key(group_id,user_id,date));
create table if not exists public.eyebible_seen(group_id uuid not null references public.eyebible_groups(id),user_id uuid not null references auth.users(id) on delete cascade,activity text not null check(length(activity)<=42),primary key(group_id,user_id,activity));
create table if not exists public.eyebible_operations(user_id uuid not null references auth.users(id) on delete cascade,operation_id uuid not null,group_id uuid not null references public.eyebible_groups(id),action text not null,primary key(user_id,operation_id));
-- Browser access is exclusively through the two narrow RPCs; no direct table privileges.
do $$ declare t text; begin
 foreach t in array array['eyebible_groups','eyebible_members','eyebible_blocks','eyebible_posts','eyebible_replies','eyebible_reactions','eyebible_completions','eyebible_seen','eyebible_operations'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end $$;
-- Only the guarded writer calls this helper; malformed snapshots never enter shared storage.
create or replace function public.eyebible_scripture(input jsonb,verse_index integer)
returns jsonb language plpgsql set search_path=pg_catalog,public as $$
declare v jsonb; verses jsonb:='[]'; ids text[]:='{}'; selected date;
begin
 if input is null then
  if verse_index is not null then raise exception 'Verse requires a scripture snapshot' using errcode='22023';end if;
  return null;
 end if;
 if jsonb_typeof(input)<>'object' or input->'schemaVersion' is distinct from '1'::jsonb or jsonb_typeof(input->'date') is distinct from 'string' or jsonb_typeof(input->'reference') is distinct from 'string' or length(trim(input->>'reference')) not between 1 and 200 or jsonb_typeof(input->'title') is distinct from 'string' or jsonb_typeof(input->'verses') is distinct from 'array' or octet_length(input::text)>200000 then raise exception 'Invalid scripture snapshot' using errcode='22023';end if;
 begin selected:=(input->>'date')::date;exception when others then raise exception 'Invalid scripture date' using errcode='22023';end;
 if selected::text<>input->>'date' or selected>(now() at time zone 'Asia/Taipei')::date or jsonb_array_length(input->'verses') not between 1 and 500 or (verse_index is not null and verse_index not between 1 and jsonb_array_length(input->'verses')) then raise exception 'Invalid scripture range' using errcode='22023';end if;
 for v in select jsonb_array_elements(input->'verses') loop
  if jsonb_typeof(v)<>'object' or jsonb_typeof(v->'id') is distinct from 'string' or length(v->>'id') not between 1 and 100 or (v->>'id')=any(ids) or jsonb_typeof(v->'book') is distinct from 'string' or length(v->>'book') not between 1 and 100 or jsonb_typeof(v->'reference') is distinct from 'string' or length(v->>'reference') not between 1 and 200 or jsonb_typeof(v->'text') is distinct from 'string' or length(trim(v->>'text')) not between 1 and 10000 or coalesce(v->>'chapter','') !~ '^[1-9][0-9]{0,3}$' or coalesce(v->>'verse','') !~ '^[1-9][0-9]{0,3}$' or jsonb_typeof(v->'chapter') is distinct from 'number' or jsonb_typeof(v->'verse') is distinct from 'number' then raise exception 'Invalid scripture verse' using errcode='22023';end if;
  ids:=array_append(ids,v->>'id');verses:=verses||jsonb_build_array(jsonb_build_object('id',v->>'id','book',v->>'book','chapter',(v->>'chapter')::int,'verse',(v->>'verse')::int,'reference',v->>'reference','text',v->>'text'));
 end loop;
 return jsonb_build_object('schemaVersion',1,'date',selected::text,'reference',input->>'reference','title',input->>'title','verses',verses);
end $$;
revoke all on function public.eyebible_scripture(jsonb,integer) from public,anon,authenticated;
create or replace function public.group_action(p_action text,p_data jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid(); m public.eyebible_members; g public.eyebible_groups; p public.eyebible_posts; r public.eyebible_replies;
 target uuid; operation uuid; receipt public.eyebible_operations; snapshot jsonb; profile jsonb; item text; code text; selected date; affected text;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>700000 then raise exception 'Invalid group request' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 if p_action in ('preview','join') then
  code:=trim(p_data->>'code');
  select * into g from public.eyebible_groups where invite_code=code and invite_expires_at>now() for update;
  if not found then raise exception 'Invitation invalid or expired' using errcode='22023'; end if;
  if exists(select 1 from public.eyebible_blocks where group_id=g.id and user_id=actor) then raise exception 'Leader approval required' using errcode='42501'; end if;
  if p_action='preview' then return jsonb_build_object('id',g.id,'name',g.name,'expires_at',g.invite_expires_at); end if;
  if exists(select 1 from public.eyebible_members where user_id=actor and group_id<>g.id) then raise exception 'Leave current group first' using errcode='23505'; end if;
 elsif p_action='create' then
  if exists(select 1 from public.eyebible_members where user_id=actor) then raise exception 'Already a member' using errcode='23505'; end if;
  insert into public.eyebible_groups(name,owner_id) values(trim(p_data->>'name'),actor) returning * into g;
 else
  select * into m from public.eyebible_members where user_id=actor;
  if not found or (p_data->>'group_id')::uuid is distinct from m.group_id then raise exception 'Group membership required' using errcode='42501'; end if;
  select * into g from public.eyebible_groups where id=m.group_id for update;
  -- Recheck after acquiring the shared group lock: removal may have happened while waiting.
  select * into m from public.eyebible_members where user_id=actor and group_id=g.id;
  if not found then raise exception 'Group membership required' using errcode='42501'; end if;
 end if;
 if p_action in ('amen','complete','profile') then
  operation:=(p_data->>'operation_id')::uuid;
  if operation is null then raise exception 'Stable operation ID required' using errcode='22023';end if;
  select * into receipt from public.eyebible_operations where user_id=actor and operation_id=operation;
  if found then
   if receipt.group_id<>g.id or receipt.action<>p_action then raise exception 'Operation context mismatch' using errcode='42501';end if;
   return jsonb_build_object('ok',true,'duplicate',true);
  end if;
  insert into public.eyebible_operations values(actor,operation,g.id,p_action);
 end if;
 if p_action in ('create','join','profile') then
  profile:=coalesce(p_data->'profile','{}'::jsonb);
  insert into public.eyebible_members(user_id,group_id,name,avatar,image)
   values(actor,g.id,coalesce(nullif(trim(profile->>'name'),''),'我'),coalesce(profile->>'avatar','🌿'),coalesce(profile->>'image',''))
   on conflict(user_id) do update set name=excluded.name,avatar=excluded.avatar,image=excluded.image;
  return jsonb_build_object('id',g.id,'name',g.name)||case when g.owner_id=actor then jsonb_build_object('invite_code',g.invite_code,'invite_expires_at',g.invite_expires_at) else '{}'::jsonb end;
 elsif p_action in ('rotate','remove','unblock') then
  if g.owner_id<>actor then raise exception 'Leader required' using errcode='42501'; end if;
  if p_action='rotate' then
   update public.eyebible_groups set invite_code=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),invite_expires_at=now()+interval '30 days' where id=g.id returning * into g;
   return jsonb_build_object('invite_code',g.invite_code,'invite_expires_at',g.invite_expires_at);
  end if;
  target:=(p_data->>'user_id')::uuid;
  if target is null or target=actor then raise exception 'Invalid member' using errcode='22023'; end if;
  if p_action='unblock' then delete from public.eyebible_blocks where group_id=g.id and user_id=target;
  else
   insert into public.eyebible_blocks(group_id,user_id,name) select g.id,user_id,name from public.eyebible_members where user_id=target and group_id=g.id on conflict do nothing;
   delete from public.eyebible_members where user_id=target and group_id=g.id;
  end if;
 elsif p_action='leave' then
  if g.owner_id=actor then raise exception 'Leader cannot leave' using errcode='42501'; end if;
  delete from public.eyebible_members where user_id=actor and group_id=g.id;
 elsif p_action='complete' then
  selected:=(p_data->>'date')::date;
  if selected is null or selected>(now() at time zone 'Asia/Taipei')::date or selected<'1900-01-01'::date then raise exception 'Invalid completion date' using errcode='22023'; end if;
  if (p_data->>'active')::boolean then insert into public.eyebible_completions values(g.id,actor,selected) on conflict do nothing;
  else delete from public.eyebible_completions where group_id=g.id and user_id=actor and date=selected; end if;
 elsif p_action='read' then
  if jsonb_typeof(p_data->'activities') is distinct from 'array' or jsonb_array_length(p_data->'activities')>200 then raise exception 'Invalid read markers' using errcode='22023'; end if;
  for item in select jsonb_array_elements_text(p_data->'activities') loop
   if exists(select 1 from public.eyebible_posts where group_id=g.id and deleted_at is null and item='post:'||id::text)
    or exists(select 1 from public.eyebible_replies rr join public.eyebible_posts pp on pp.id=rr.post_id where pp.group_id=g.id and pp.deleted_at is null and rr.deleted_at is null and item='reply:'||rr.id::text) then
    insert into public.eyebible_seen values(g.id,actor,item) on conflict do nothing;
   end if;
  end loop;
 elsif p_action='post' then
  operation:=(p_data->>'id')::uuid;
  profile:=jsonb_build_object('name',m.name,'avatar',m.avatar,'image','');
  snapshot:=public.eyebible_scripture(p_data->'reading',(p_data->>'verse')::integer);
  insert into public.eyebible_posts(id,group_id,author_id,author,text,reference,quote,reading,verse)
   values(operation,g.id,actor,profile,trim(p_data->>'text'),coalesce(p_data->>'reference',''),coalesce(p_data->>'quote',''),snapshot,(p_data->>'verse')::integer) on conflict(id) do nothing;
  if not exists(select 1 from public.eyebible_posts where id=operation and author_id=actor and group_id=g.id) then raise exception 'Operation ID belongs to another author' using errcode='42501'; end if;
 else
  select * into p from public.eyebible_posts where id=(p_data->>'post_id')::uuid and group_id=g.id;
  if not found then raise exception 'Shared post unavailable' using errcode='42501'; end if;
  if p.deleted_at is not null then
   if p_action='delete' and (p.author_id=actor or g.owner_id=actor) then return jsonb_build_object('ok',true); end if;
   raise exception 'Shared post unavailable' using errcode='42501';
  end if;
  if p_action='reply' then
   operation:=(p_data->>'id')::uuid;
   insert into public.eyebible_replies(id,post_id,author_id,author,text) values(operation,p.id,actor,jsonb_build_object('name',m.name,'avatar',m.avatar,'image',''),trim(p_data->>'text')) on conflict(id) do nothing;
   if not exists(select 1 from public.eyebible_replies where id=operation and post_id=p.id and author_id=actor) then raise exception 'Operation ID belongs to another author' using errcode='42501'; end if;
  elsif p_action='amen' then
   if (p_data->>'active')::boolean then insert into public.eyebible_reactions values(p.id,actor) on conflict do nothing;
   else delete from public.eyebible_reactions where post_id=p.id and user_id=actor; end if;
  elsif p_action='delete' then
   if p_data ? 'reply_id' then
    update public.eyebible_replies set deleted_at=now() where id=(p_data->>'reply_id')::uuid and post_id=p.id and (author_id=actor or g.owner_id=actor);
   else
    update public.eyebible_posts set deleted_at=now() where id=p.id and (author_id=actor or g.owner_id=actor);
   end if;
   if not found then raise exception 'Author or leader required' using errcode='42501'; end if;
  else raise exception 'Unknown group action' using errcode='22023'; end if;
 end if;
 return jsonb_build_object('ok',true);
end $$;

create or replace function public.group_read(p_mode text default 'overview',p_day date default null,p_before timestamptz default null,p_before_id uuid default null,p_post_id uuid default null)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid(); g public.eyebible_groups; start_at timestamptz; end_at timestamptz; posts jsonb:='[]'; members jsonb; blocked jsonb; unread integer; next_cursor jsonb; extra boolean;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select gg.* into g from public.eyebible_groups gg join public.eyebible_members mm on mm.group_id=gg.id where mm.user_id=actor;
 if not found then return jsonb_build_object('group',null,'posts','[]'::jsonb,'members','[]'::jsonb,'unread',0); end if;
 if p_mode not in ('overview','recent','archive','replies') then raise exception 'Invalid read mode' using errcode='22023'; end if;
 if p_mode='archive' then
  if p_day is null then raise exception 'Archive date required' using errcode='22023'; end if;
  start_at:=p_day::timestamp at time zone 'Asia/Taipei';end_at:=(p_day+1)::timestamp at time zone 'Asia/Taipei';
 else start_at:=((now() at time zone 'Asia/Taipei')::date-6)::timestamp at time zone 'Asia/Taipei';end_at:=clock_timestamp();end if;
 if p_mode='replies' then
  if not exists(select 1 from public.eyebible_posts where id=p_post_id and group_id=g.id and deleted_at is null) then raise exception 'Shared post unavailable' using errcode='42501'; end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q."createdAt",q.id),'[]'::jsonb) into posts from (
   select rr.id,rr.author_id as "authorId",rr.author->>'name' as name,rr.author->>'avatar' as avatar,''::text as image,rr.text,rr.created_at as "createdAt",not exists(select 1 from public.eyebible_seen where group_id=g.id and user_id=actor and activity='reply:'||rr.id::text) as unseen
   from public.eyebible_replies rr where rr.post_id=p_post_id and rr.deleted_at is null and (p_before is null or (rr.created_at,rr.id)>(p_before,coalesce(p_before_id,'00000000-0000-0000-0000-000000000000'::uuid))) order by rr.created_at,rr.id limit 101
  )q;
  extra:=jsonb_array_length(posts)>100;posts:=case when extra then posts-100 else posts end;
  return jsonb_build_object('group_id',g.id,'replies',posts,'more',extra);
 end if;
 if p_mode<>'overview' then
  select coalesce(jsonb_agg(to_jsonb(q) order by q."createdAt" desc,q.id desc),'[]'::jsonb) into posts from (
   select pp.id,pp.author_id as "authorId",coalesce(mm.name,pp.author->>'name','已離開的成員') as name,coalesce(mm.avatar,pp.author->>'avatar','🌿') as avatar,''::text as image,
    pp.text,pp.reference,pp.quote,pp.reading,pp.verse,pp.created_at as "createdAt",(pp.created_at at time zone 'Asia/Taipei')::date as date,
    (select count(*) from public.eyebible_reactions where post_id=pp.id) as likes,
    exists(select 1 from public.eyebible_reactions where post_id=pp.id and user_id=actor) as liked,
    (select count(*) from public.eyebible_replies where post_id=pp.id and deleted_at is null) as "replyCount",
    coalesce((select jsonb_agg(to_jsonb(r) order by r."createdAt",r.id) from (
     select rr.id,rr.author_id as "authorId",coalesce(rm.name,rr.author->>'name') as name,coalesce(rm.avatar,rr.author->>'avatar') as avatar,''::text as image,rr.text,rr.created_at as "createdAt"
     from public.eyebible_replies rr left join public.eyebible_members rm on rm.user_id=rr.author_id and rm.group_id=g.id where rr.post_id=pp.id and rr.deleted_at is null order by rr.created_at,rr.id limit 100
    )r),'[]'::jsonb) as replies,
    coalesce((select jsonb_agg(activity) from (
     select 'post:'||pp.id::text as activity where not exists(select 1 from public.eyebible_seen where group_id=g.id and user_id=actor and activity='post:'||pp.id::text)
     union all select 'reply:'||rr.id::text from (select id from public.eyebible_replies where post_id=pp.id and deleted_at is null order by created_at,id limit 100)rr where not exists(select 1 from public.eyebible_seen where group_id=g.id and user_id=actor and activity='reply:'||rr.id::text)
    )s),'[]'::jsonb) as unseen
   from public.eyebible_posts pp left join public.eyebible_members mm on mm.user_id=pp.author_id and mm.group_id=g.id
   where pp.group_id=g.id and pp.deleted_at is null and pp.created_at>=start_at and pp.created_at<end_at
    and (p_before is null or (pp.created_at,pp.id)<(p_before,coalesce(p_before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
   order by pp.created_at desc,pp.id desc limit 21
  )q;
  extra:=jsonb_array_length(posts)>20;posts:=case when extra then posts-20 else posts end;
  if extra then next_cursor:=jsonb_build_object('time',posts->19->>'createdAt','id',posts->19->>'id');end if;
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',mm.user_id,'name',mm.name,'avatar',mm.avatar,'image',mm.image,'dates',coalesce((select jsonb_agg(cc.date order by cc.date) from public.eyebible_completions cc where cc.group_id=g.id and cc.user_id=mm.user_id),'[]'::jsonb)) order by mm.joined_at),'[]'::jsonb) into members from public.eyebible_members mm where mm.group_id=g.id;
 select coalesce(jsonb_agg(jsonb_build_object('id',bb.user_id,'name',bb.name)),'[]'::jsonb) into blocked from public.eyebible_blocks bb where bb.group_id=g.id and g.owner_id=actor;
 select count(*) into unread from (
  select 'post:'||pp.id::text as activity from public.eyebible_posts pp where pp.group_id=g.id and pp.deleted_at is null and pp.author_id is distinct from actor and pp.created_at>=((now() at time zone 'Asia/Taipei')::date-6)::timestamp at time zone 'Asia/Taipei'
  union all
  select 'reply:'||rr.id::text from public.eyebible_replies rr join public.eyebible_posts pp on pp.id=rr.post_id where pp.group_id=g.id and pp.deleted_at is null and rr.deleted_at is null and rr.author_id is distinct from actor and pp.created_at>=((now() at time zone 'Asia/Taipei')::date-6)::timestamp at time zone 'Asia/Taipei'
 )s where not exists(select 1 from public.eyebible_seen where group_id=g.id and user_id=actor and activity=s.activity);
 return jsonb_build_object('group',jsonb_build_object('id',g.id,'name',g.name,'owner_id',g.owner_id)||case when g.owner_id=actor then jsonb_build_object('invite_code',g.invite_code,'invite_expires_at',g.invite_expires_at) else '{}'::jsonb end,'members',members,'blocked',blocked,'posts',posts,'next',next_cursor,'unread',unread);
end $$;
revoke all on function public.group_action(text,jsonb) from public,anon;
revoke all on function public.group_read(text,date,timestamptz,uuid,uuid) from public,anon;
grant execute on function public.group_action(text,jsonb) to authenticated;
grant execute on function public.group_read(text,date,timestamptz,uuid,uuid) to authenticated;
commit;
