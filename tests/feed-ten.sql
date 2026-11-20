-- New wall contract; run only in disposable test database after groups-db.sh.
do $$ begin if to_regprocedure('public.group_feed(jsonb)') is null then raise exception 'Missing all-history ten-post feed RPC';end if;end $$;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare g text:=public.group_read()->'group'->>'id';r jsonb;cursor jsonb;counted int:=0;ids text[]:='{}';p jsonb;begin
 perform public.group_action('reply',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','id','aaaaaaaa-1111-4111-8111-111111111111','text','Reply makes old thread visible first'));
 r:=public.group_feed();if jsonb_array_length(r->'posts')<>10 then raise exception 'Feed must load exactly ten at a time';end if;
 if r->'posts'->0->>'id'<>'44444444-4444-4444-8444-444444444444' then raise exception 'Replied old post was not pinned first';end if;
 perform public.group_action('amen',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','reply_id','aaaaaaaa-1111-4111-8111-111111111111','active',true,'operation_id','aaaaaaaa-2222-4222-8222-222222222221'));
 r:=public.group_feed();if (r->'posts'->0->'replies'->0->>'likes')::int<>1 or r->'posts'->0->'replies'->0->'liked'<>'true'::jsonb then raise exception 'Reply Amen missing';end if;
 perform public.group_action('amen',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','reply_id','aaaaaaaa-1111-4111-8111-111111111111','active',false,'operation_id','aaaaaaaa-2222-4222-8222-222222222222'));
 perform public.group_action('amen',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','reply_id','aaaaaaaa-1111-4111-8111-111111111111','active',true,'operation_id','aaaaaaaa-2222-4222-8222-222222222221'));
 r:=public.group_feed();if (r->'posts'->0->'replies'->0->>'likes')::int<>0 then raise exception 'Old reply Amen retry reversed later choice';end if;
 perform public.group_action('post',jsonb_build_object('group_id',g,'id','99999999-1111-4111-8111-111111111111','text','fresh direct share'));
 r:=public.group_feed();if r->'posts'->0->>'id'<>'99999999-1111-4111-8111-111111111111' then raise exception 'Fresh direct post must precede older replied thread';end if;
 perform public.group_action('reply',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','id','aaaaaaaa-1111-4111-8111-111111111112','text','newer reply moves old thread above fresh post'));
 r:=public.group_feed();if r->'posts'->0->>'id'<>'44444444-4444-4444-8444-444444444444' then raise exception 'New reply must promote by activity time';end if;
 loop
  for p in select jsonb_array_elements(r->'posts') loop
   if (p->>'id')=any(ids) then raise exception 'Duplicate feed page item';end if;
   ids:=array_append(ids,p->>'id');counted:=counted+1;
  end loop;
  cursor:=r->'next';exit when cursor is null or cursor='null'::jsonb;
  r:=public.group_feed(cursor);if jsonb_array_length(r->'posts')>10 then raise exception 'Older page exceeds ten';end if;
 end loop;
 if counted<22 then raise exception 'Old history cut off by seven-day filter';end if;
 perform public.group_action('delete',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','reply_id','aaaaaaaa-1111-4111-8111-111111111111'));
 begin perform public.group_action('amen',jsonb_build_object('group_id',g,'post_id','44444444-4444-4444-8444-444444444444','reply_id','aaaaaaaa-1111-4111-8111-111111111111','active',true,'operation_id','aaaaaaaa-2222-4222-8222-222222222223'));raise exception 'Amen on deleted reply allowed';exception when insufficient_privilege then null;end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
do $$ declare g text:=public.group_read()->'group'->>'id';begin
 perform public.group_action('post',jsonb_build_object('group_id',g,'id','bbbbbbbb-3333-4333-8333-333333333333','text','own valid parent'));
 begin perform public.group_action('amen',jsonb_build_object('group_id',g,'post_id','bbbbbbbb-3333-4333-8333-333333333333','reply_id','22222222-2222-4222-8222-222222222222','active',true,'operation_id','bbbbbbbb-2222-4222-8222-222222222223'));raise exception 'Cross-group reply reaction allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
set role anon;
do $$ begin begin perform public.group_feed();raise exception 'Anonymous feed access';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'PASS ten-post all-history wall, reply pinning, reply Amen/receipts and isolation';
