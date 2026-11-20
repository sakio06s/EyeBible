-- Disposable database only. Admin seeded as actor1 by the private upgrade fixture.
do $$ begin if to_regprocedure('public.feedback_read(text,timestamptz,uuid)') is null then raise exception 'Missing in-app support RPC';end if;end $$;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ declare r jsonb;blocked boolean:=false;begin
 r:=public.feedback_read();if (r->>'is_admin')::boolean or jsonb_array_length(r->'reports')<>0 then raise exception 'Member can see administrator list';end if;
 perform public.feedback_action('submit','{"id":"11111111-aaaa-4111-8111-111111111111","text":"第一個問題","name":"組員"}');
 perform public.feedback_action('submit','{"id":"11111111-aaaa-4111-8111-111111111111","text":"第一個問題","name":"新的名字"}');
 begin perform public.feedback_action('resolve','{"id":"11111111-aaaa-4111-8111-111111111111"}');exception when insufficient_privilege then blocked:=true;end;if not blocked then raise exception 'Member resolved report';end if;
 blocked:=false;begin perform public.feedback_action('delete','{"id":"11111111-aaaa-4111-8111-111111111111"}');exception when insufficient_privilege then blocked:=true;end;if not blocked then raise exception 'Member deleted report';end if;
 r:=public.feedback_read('list');if jsonb_array_length(r->'reports')<>0 then raise exception 'Member read reports';end if;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
do $$ declare blocked boolean:=false;begin
 if (public.feedback_read()->>'is_admin')::boolean then raise exception 'Other group leader became app admin';end if;
 begin perform public.feedback_action('submit','{"id":"11111111-aaaa-4111-8111-111111111111","text":"stolen operation"}');exception when insufficient_privilege then blocked:=true;end;if not blocked then raise exception 'Other actor reused report ID';end if;
 perform public.feedback_action('submit','{"id":"22222222-aaaa-4222-8222-222222222222","text":"第二個問題","name":"另一組組長"}');
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare r jsonb;begin
 r:=public.feedback_read();if r->>'is_admin'<>'true' or (r->>'unread')::int<>2 or jsonb_array_length(r->'reports')<>0 then raise exception 'Admin overview/unread incorrect';end if;
 r:=public.feedback_read('list');if jsonb_array_length(r->'reports')<>2 or (r->>'unread')::int<>0 then raise exception 'List dedupe or read markers incorrect';end if;
 r:=public.feedback_action('resolve','{"id":"11111111-aaaa-4111-8111-111111111111"}');if r->'report'->>'resolvedAt' is null then raise exception 'Resolve missing';end if;
 perform public.feedback_action('resolve','{"id":"11111111-aaaa-4111-8111-111111111111"}');
 r:=public.feedback_action('delete','{"id":"22222222-aaaa-4222-8222-222222222222"}');if r->>'deleted_id'<>'22222222-aaaa-4222-8222-222222222222' then raise exception 'Delete missing';end if;
 perform public.feedback_action('delete','{"id":"22222222-aaaa-4222-8222-222222222222"}');
 r:=public.feedback_read('list');if jsonb_array_length(r->'reports')<>1 or r->'reports'->0->>'resolvedAt' is null then raise exception 'Deleted report remains';end if;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ declare limited boolean:=false;r jsonb;begin
 perform public.feedback_action('submit','{"id":"33333333-aaaa-4333-8333-333333333333","text":"第三個問題","name":"普通組員","is_admin":true,"authorId":"00000000-0000-0000-0000-000000000001"}');
 for i in 4..6 loop perform public.feedback_action('submit',jsonb_build_object('id',('00000000-aaaa-4000-8000-'||lpad(i::text,12,'0'))::uuid,'text','額外問題'||i));end loop;
 begin perform public.feedback_action('submit','{"id":"77777777-aaaa-4777-8777-777777777777","text":"too many"}');exception when raise_exception then limited:=sqlerrm='feedback_rate_limit';end;if not limited then raise exception 'Rate not enforced';end if;
 perform public.feedback_action('submit','{"id":"11111111-aaaa-4111-8111-111111111111","text":"第一個問題"}');
 r:=public.feedback_read();if (r->>'is_admin')::boolean then raise exception 'Body promoted reporter';end if;
 begin perform public.feedback_action('submit',jsonb_build_object('id',gen_random_uuid(),'text',repeat('x',2001)));raise exception 'Oversized message accepted';exception when invalid_parameter_value then null;end;
end $$;
reset role;
do $$ begin if (select provided_by from public.eyebible_feedback where id='33333333-aaaa-4333-8333-333333333333')<>'00000000-0000-0000-0000-000000000002' then raise exception 'Actor spoofed';end if;end $$;
set role anon;
do $$ begin begin perform public.feedback_read();raise exception 'Anonymous list';exception when insufficient_privilege then null;end;begin perform public.feedback_action('submit','{}');raise exception 'Anonymous submit';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'PASS support: admin isolation, authenticated reporter, idempotency, unread/list/status/delete, rate, bounds';
