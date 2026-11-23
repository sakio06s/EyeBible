do $$ declare r jsonb;begin
 if exists(select 1 from public.eyebible_posts where deleted_at is null or text<>'[已清除]' or quote<>'' or reading is not null) then raise exception 'Posts not cleared';end if;
 if exists(select 1 from public.eyebible_replies where deleted_at is null or text<>'[已清除]') then raise exception 'Replies not cleared';end if;
 if (select count(*) from public.eyebible_reactions)+(select count(*) from public.eyebible_reply_reactions)+(select count(*) from public.eyebible_seen)<>0 then raise exception 'Reactions/markers remain';end if;
 if (select count(*) from public.eyebible_posts)<>13 or (select count(*) from public.eyebible_replies)<>4 then raise exception 'Retry tombstones lost';end if;
 if exists(select 1 from public.personal_states where revision<>4) then raise exception 'Revision not advanced';end if;
 for r in select payload->'records' from public.personal_states loop
  if r is distinct from jsonb_build_object(
   '["note","private"]',jsonb_build_object('id','private','text','PRIVATE_SECRET_SENTINEL','private',true),
   '["setting","name"]','keep name','["fullMarks","2026-11-23","1"]','yellow','["checkins","2026-11-23"]',true)
  then raise exception 'Private state changed';end if;
 end loop;
 if exists(select 1 from tagbible_maintenance_private.discussion_backup where row_data::text like '%PRIVATE_SECRET_SENTINEL%') then raise exception 'Private note copied to backup';end if;
 if (select count(*) from tagbible_maintenance_private.discussion_backup where category='posts')<>13 then raise exception 'Post backup incomplete';end if;
 if exists((select category,row_data from public.maintenance_test_preserved) except (select 'groups',to_jsonb(t) from public.eyebible_groups t union all select 'members',to_jsonb(t) from public.eyebible_members t union all select 'completions',to_jsonb(t) from public.eyebible_completions t union all select 'operations',to_jsonb(t) from public.eyebible_operations t)) then raise exception 'Preserved entities changed';end if;
end $$;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$begin
 if public.group_capabilities()->'can_create_group'<>'false'::jsonb then raise exception 'Member can create';end if;
 begin perform * from tagbible_maintenance_private.discussion_backup;raise exception 'Backup exposed';exception when insufficient_privilege then null;end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000005';
do $$begin
 begin perform public.group_action('create','{"name":"forged","is_admin":true}');raise exception 'Nonadmin create allowed';exception when insufficient_privilege then null;end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.group_action('post',jsonb_build_object('group_id','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','id',md5('post1')::uuid,'text','late retry'));
do $$begin
 if jsonb_array_length(public.group_feed()->'posts')<>0 then raise exception 'Late retry resurrected post';end if;
 begin perform public.save_personal_state(3,'{"schemaVersion":1,"records":{}}');raise exception 'Stale personal save allowed';exception when serialization_failure then null;end;
end $$;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000004';
do $$begin if public.group_capabilities()->'can_create_group'<>'true'::jsonb then raise exception 'Admin denied';end if;end $$;
select public.group_action('create','{"name":"admin-created"}');
reset role;
set role anon;
do $$begin
 begin perform public.group_capabilities();raise exception 'Anonymous capability read allowed';exception when insufficient_privilege then null;end;
 begin insert into public.eyebible_groups(name,owner_id) values('anon','00000000-0000-0000-0000-000000000005');raise exception 'Anonymous table create allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
