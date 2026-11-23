create table public.eyebible_app_admins(user_id uuid primary key references auth.users(id));
alter table public.eyebible_app_admins enable row level security;
revoke all on public.eyebible_app_admins from public,anon,authenticated;
insert into public.eyebible_app_admins values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000004');
create function public.eyebible_is_app_admin(actor uuid) returns boolean language sql stable security definer set search_path=pg_catalog,public as $$ select actor is not null and exists(select 1 from public.eyebible_app_admins where user_id=actor) $$;
revoke all on function public.eyebible_is_app_admin(uuid) from public,anon,authenticated;
insert into public.eyebible_groups(id,name,owner_id) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','group one','00000000-0000-0000-0000-000000000001'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','group two','00000000-0000-0000-0000-000000000003');
insert into public.eyebible_members(user_id,group_id,name) values
 ('00000000-0000-0000-0000-000000000001','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','admin'),
 ('00000000-0000-0000-0000-000000000002','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','member'),
 ('00000000-0000-0000-0000-000000000003','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','leader');
insert into public.eyebible_posts(id,group_id,author_id,author,text,reference,quote)
 select md5('post'||n)::uuid,case when n<=7 then 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' else 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' end::uuid,
 case when n<=7 then '00000000-0000-0000-0000-000000000001' else '00000000-0000-0000-0000-000000000003' end::uuid,
 '{"name":"public author"}', 'public post '||n,'passage','public quote' from generate_series(1,13)n;
insert into public.eyebible_replies(id,post_id,author_id,author,text)
 select md5('reply'||n)::uuid,md5('post'||n)::uuid,'00000000-0000-0000-0000-000000000002','{"name":"public author"}','public reply '||n from generate_series(1,4)n;
insert into public.eyebible_reactions select md5('post'||n)::uuid,'00000000-0000-0000-0000-000000000002' from generate_series(1,3)n;
insert into public.eyebible_reply_reactions values(md5('reply1')::uuid,'00000000-0000-0000-0000-000000000002');
insert into public.eyebible_seen values('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','00000000-0000-0000-0000-000000000001','post:'||md5('post1')::uuid::text);
insert into public.eyebible_completions values('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','00000000-0000-0000-0000-000000000001','2026-11-23');
insert into public.eyebible_operations values('00000000-0000-0000-0000-000000000001',md5('operation1')::uuid,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','complete');
insert into public.personal_states(user_id,revision,payload)
 select ('00000000-0000-0000-0000-'||lpad(u::text,12,'0'))::uuid,3,
 jsonb_build_object('schemaVersion',1,'records',
 jsonb_build_object('["note","private"]',jsonb_build_object('id','private','text','PRIVATE_SECRET_SENTINEL','private',true),
 '["setting","name"]','keep name','["fullMarks","2026-11-23","1"]','yellow','["checkins","2026-11-23"]',true,
 '["reply","old-post","old-reply"]',jsonb_build_object('id','old-reply','text','old public reply'),
 '["likes","old-post"]',true,'["seenActivity","old-post"]',true)
 ||(select jsonb_object_agg('["note","public-'||n||'"]',jsonb_build_object('id','public-'||n,'kind',case when n%2=0 then 'group' else 'general' end,'text','public note '||n,'private',false)) from generate_series((u-1)*7+1,u*7)n))
 from generate_series(1,2)u;
create table public.maintenance_test_preserved as select 'groups' as category,to_jsonb(t) as row_data from public.eyebible_groups t
 union all select 'members',to_jsonb(t) from public.eyebible_members t
 union all select 'completions',to_jsonb(t) from public.eyebible_completions t
 union all select 'operations',to_jsonb(t) from public.eyebible_operations t;
