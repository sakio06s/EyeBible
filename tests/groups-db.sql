-- Only run through the disposable Docker harness.
do $$ begin if to_regprocedure('public.group_action(text,jsonb)') is null then raise exception 'Missing group_action RPC'; end if; end $$;
insert into auth.users values ('00000000-0000-0000-0000-000000000003') on conflict do nothing;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.group_action('create','{"name":"EyeBible 小組","profile":{"name":"Alice","avatar":"🌿"}}') as created \gset
select (:'created'::jsonb->>'id') as gid, (:'created'::jsonb->>'invite_code') as code \gset
do $$ begin
 if abs(extract(epoch from ((public.group_read()->'group'->>'invite_expires_at')::timestamptz-now()))-30*86400)>5 then raise exception 'Invite must expire in 30 days'; end if;
 begin perform public.group_action('create','{"name":"duplicate"}'); raise exception 'Two memberships allowed'; exception when unique_violation then null; end;
 begin perform * from public.eyebible_groups; raise exception 'Direct table access allowed'; exception when insufficient_privilege then null; end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
select public.group_action('preview',jsonb_build_object('code',:'code'));
select public.group_action('join',jsonb_build_object('code',:'code','profile',jsonb_build_object('name','Bob','avatar','🐻')));
select public.group_action('post',jsonb_build_object('group_id',:'gid','id','11111111-1111-4111-8111-111111111111','text','shared','reference','約翰福音 3:16'));
select public.group_action('post',jsonb_build_object('group_id',:'gid','id','11111111-1111-4111-8111-111111111111','text','shared'));
select public.group_action('reply',jsonb_build_object('group_id',:'gid','post_id','11111111-1111-4111-8111-111111111111','id','22222222-2222-4222-8222-222222222222','text','Amen reply'));
select public.group_action('amen',jsonb_build_object('group_id',:'gid','post_id','11111111-1111-4111-8111-111111111111','active',true,'operation_id','77777777-7777-4777-8777-777777777771'));
select public.group_action('amen',jsonb_build_object('group_id',:'gid','post_id','11111111-1111-4111-8111-111111111111','active',true,'operation_id','77777777-7777-4777-8777-777777777771'));
select public.group_action('complete',jsonb_build_object('group_id',:'gid','date',(now() at time zone 'Asia/Taipei')::date,'active',true,'operation_id','77777777-7777-4777-8777-777777777772'));
do $$ declare r jsonb; begin
 r:=public.group_read('recent');
 if jsonb_array_length(r->'posts')<>1 then raise exception 'Duplicate post retry'; end if;
 if (r->'posts'->0->>'likes')::int<>1 then raise exception 'Duplicate Amen retry'; end if;
 if jsonb_array_length(r->'posts'->0->'replies')<>1 then raise exception 'Reply missing'; end if;
 if (r->'posts'->0->>'authorId')<>'00000000-0000-0000-0000-000000000002' then raise exception 'Author not derived from session'; end if;
 begin perform public.group_action('post',jsonb_build_object('group_id',r->'group'->>'id','id','55555555-5555-4555-8555-555555555555','text','invalid reading','reading','{}'::jsonb)); raise exception 'Invalid scripture snapshot accepted'; exception when invalid_parameter_value then null; end;
 -- A lost acknowledgement of a set operation cannot undo a newer opposite choice.
 perform public.group_action('amen',jsonb_build_object('group_id',r->'group'->>'id','post_id','11111111-1111-4111-8111-111111111111','active',true,'operation_id','66666666-6666-4666-8666-666666666661'));
 perform public.group_action('amen',jsonb_build_object('group_id',r->'group'->>'id','post_id','11111111-1111-4111-8111-111111111111','active',false,'operation_id','66666666-6666-4666-8666-666666666662'));
 perform public.group_action('amen',jsonb_build_object('group_id',r->'group'->>'id','post_id','11111111-1111-4111-8111-111111111111','active',true,'operation_id','66666666-6666-4666-8666-666666666661'));
 if (public.group_read('recent')->'posts'->0->>'likes')::int<>0 then raise exception 'Stale Amen retry overwrote newer choice'; end if;
 perform public.group_action('complete',jsonb_build_object('group_id',r->'group'->>'id','date',(now() at time zone 'Asia/Taipei')::date,'active',true,'operation_id','66666666-6666-4666-8666-666666666663'));
 perform public.group_action('complete',jsonb_build_object('group_id',r->'group'->>'id','date',(now() at time zone 'Asia/Taipei')::date,'active',false,'operation_id','66666666-6666-4666-8666-666666666664'));
 perform public.group_action('complete',jsonb_build_object('group_id',r->'group'->>'id','date',(now() at time zone 'Asia/Taipei')::date,'active',true,'operation_id','66666666-6666-4666-8666-666666666663'));
 if exists(select 1 from jsonb_array_elements(public.group_read()->'members') m where m->>'id'='00000000-0000-0000-0000-000000000002' and jsonb_array_length(m->'dates')<>0) then raise exception 'Stale checkin retry overwrote newer cancellation'; end if;
 begin perform public.group_action('post',jsonb_build_object('group_id',r->'group'->>'id','id','55555555-5555-4555-8555-555555555555','text','bad verse','reading',jsonb_build_object('schemaVersion',1,'date',(now() at time zone 'Asia/Taipei')::date,'reference','約翰福音 3:16','title','今日經文','verses',jsonb_build_array(jsonb_build_object('id','JHN.3.16','book','約翰福音','chapter',3,'verse',16,'reference','約翰福音 3:16','text','神愛世人'))),'verse',2)); raise exception 'Out-of-range verse accepted'; exception when invalid_parameter_value then null; end;
 perform public.group_action('post',jsonb_build_object('group_id',r->'group'->>'id','id','55555555-5555-4555-8555-555555555555','text','valid snapshot','reading',jsonb_build_object('schemaVersion',1,'date',(now() at time zone 'Asia/Taipei')::date,'reference','約翰福音 3:16','title','今日經文','verses',jsonb_build_array(jsonb_build_object('id','JHN.3.16','book','約翰福音','chapter',3,'verse',16,'reference','約翰福音 3:16','text','神愛世人'))),'verse',1));
 perform public.group_action('delete',jsonb_build_object('group_id',r->'group'->>'id','post_id','55555555-5555-4555-8555-555555555555'));
 if r->'group' ? 'invite_code' then raise exception 'Member reads leader invitation'; end if;
 begin perform public.group_action('rotate','{}'); raise exception 'Member rotates invite'; exception when insufficient_privilege then null; end;
 if exists(select 1 from public.personal_states where user_id<>'00000000-0000-0000-0000-000000000002') then raise exception 'Private snapshots exposed'; end if;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
select public.group_action('create','{"name":"Another group","profile":{"name":"Other"}}');
do $$ begin
 if jsonb_array_length(public.group_read('recent')->'posts')<>0 then raise exception 'Cross-group post read'; end if;
 begin perform public.group_action('reply',jsonb_build_object('group_id',public.group_read()->'group'->>'id','post_id','11111111-1111-4111-8111-111111111111','id','33333333-3333-4333-8333-333333333333','text','attack')); raise exception 'Cross-group write'; exception when insufficient_privilege then null; end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.group_action('read',jsonb_build_object('group_id',:'gid','activities',jsonb_build_array('post:11111111-1111-4111-8111-111111111111','reply:22222222-2222-4222-8222-222222222222')));
do $$ begin if (public.group_read('recent')->>'unread')::int<>0 then raise exception 'Read markers missing'; end if; end $$;
select public.group_action('remove',jsonb_build_object('group_id',:'gid','user_id','00000000-0000-0000-0000-000000000002'));
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ begin if public.group_read()->'group'<>'null'::jsonb then raise exception 'Removed member access'; end if; end $$;
select set_config('test.old_invite',:'code',false);
do $$ begin begin perform public.group_action('join',jsonb_build_object('code',current_setting('test.old_invite'))); raise exception 'Blocked member rejoined'; exception when insufficient_privilege then null; end; end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.group_action('unblock',jsonb_build_object('group_id',:'gid','user_id','00000000-0000-0000-0000-000000000002'));
select public.group_action('rotate',jsonb_build_object('group_id',:'gid')) as rotated \gset
select (:'rotated'::jsonb->>'invite_code') as code2 \gset
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ begin begin perform public.group_action('preview',jsonb_build_object('code',current_setting('test.old_invite'))); raise exception 'Rotated code still valid'; exception when invalid_parameter_value then null; end; end $$;
select public.group_action('join',jsonb_build_object('code',:'code2','profile',jsonb_build_object('name','Bob')));
select public.group_action('delete',jsonb_build_object('group_id',:'gid','post_id','11111111-1111-4111-8111-111111111111'));
select public.group_action('post',jsonb_build_object('group_id',:'gid','id','11111111-1111-4111-8111-111111111111','text','do not resurrect'));
do $$ begin if jsonb_array_length(public.group_read('recent')->'posts')<>0 then raise exception 'Deleted post resurrected'; end if; end $$;
-- Duplicate delete retry must be a successful no-op, not a permanently failed outbox item.
select public.group_action('delete',jsonb_build_object('group_id',:'gid','post_id','11111111-1111-4111-8111-111111111111'));
select public.group_action('post',jsonb_build_object('group_id',:'gid','id','44444444-4444-4444-8444-444444444444','text','historical'));
reset role;
update public.eyebible_posts set created_at=now()-interval '40 days' where id='44444444-4444-4444-8444-444444444444';
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ begin
 if jsonb_array_length(public.group_read('recent')->'posts')<>0 then raise exception 'Old post in recent feed'; end if;
 if jsonb_array_length(public.group_read('archive',((now()-interval '40 days') at time zone 'Asia/Taipei')::date)->'posts')<>1 then raise exception 'Archive lost old post'; end if;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
select public.group_action('leave',jsonb_build_object('group_id',:'gid'));
do $$ begin if public.group_read()->'group'<>'null'::jsonb then raise exception 'Departed member retains group'; end if; end $$;
reset role;
-- Pagination and expired invitations use controlled fixture timestamps in the disposable DB.
insert into public.eyebible_posts(id,group_id,author_id,author,text,created_at)
select ('99999999-9999-4999-8999-'||lpad(n::text,12,'0'))::uuid,g.id,g.owner_id,'{"name":"Alice"}', 'page '||n,now()-interval '50 days'
from public.eyebible_groups g cross join generate_series(1,21) n where g.owner_id='00000000-0000-0000-0000-000000000001';
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare r jsonb; n jsonb; d date:=((now()-interval '50 days') at time zone 'Asia/Taipei')::date; begin
 r:=public.group_read('archive',d);
 if jsonb_array_length(r->'posts')<>20 or r->'next'='null'::jsonb then raise exception 'First archive page'; end if;
 n:=public.group_read('archive',d,(r->'next'->>'time')::timestamptz,(r->'next'->>'id')::uuid);
 if jsonb_array_length(n->'posts')<>1 then raise exception 'Archive keyset lost or duplicated records'; end if;
end $$;
reset role;
update public.eyebible_groups set invite_expires_at=now()-interval '1 second' where owner_id='00000000-0000-0000-0000-000000000001';
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
select set_config('test.expired_invite',:'code2',false);
do $$ begin begin perform public.group_action('preview',jsonb_build_object('code',current_setting('test.expired_invite'))); raise exception 'Expired invitation accepted'; exception when invalid_parameter_value then null; end; end $$;
reset role;
set role anon;
do $$ begin
 begin perform public.group_read(); raise exception 'Anonymous reads group'; exception when insufficient_privilege then null; end;
 begin perform public.group_action('create','{"name":"anonymous"}'); raise exception 'Anonymous creates group'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS shared groups: authorization, 30-day invitations, membership, interactions, retention, removal and retries' as result;
