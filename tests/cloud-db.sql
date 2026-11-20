-- Test roles and auth.uid stub are supplied only by the local test harness.
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.save_personal_state(0,'{"schemaVersion":1,"records":{}}'::jsonb);
select public.save_personal_state(1,'{"schemaVersion":1,"records":{"note":"private"}}'::jsonb);
do $$ begin
 if (select revision from public.personal_states) <> 2 then raise exception 'Alice update lost'; end if;
 begin perform public.save_personal_state(1,'{"schemaVersion":1,"records":{}}'::jsonb); raise exception 'Stale overwrite allowed'; exception when serialization_failure then null; end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ begin if (select count(*) from public.personal_states)<>0 then raise exception 'Bob reads Alice'; end if; end $$;
select public.save_personal_state(0,'{"schemaVersion":1,"records":{"note":"Bob"}}'::jsonb);
do $$ begin if (select count(*) from public.personal_states)<>1 then raise exception 'Bob isolation failed'; end if; end $$;
reset role;
set role anon;
do $$ begin
 begin perform * from public.personal_states; raise exception 'Anonymous read allowed'; exception when insufficient_privilege then null; end;
 begin perform public.save_personal_state(0,'{}'); raise exception 'Anonymous save allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
