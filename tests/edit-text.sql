begin;
insert into public.eyebible_groups(id,name,owner_id) values('10000000-0000-0000-0000-000000000001','Edit test','00000000-0000-0000-0000-000000000001');
insert into public.eyebible_members(user_id,group_id,name) values('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Leader'),('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','Author');
insert into public.eyebible_posts(id,group_id,author_id,author,text,created_at) values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','{}','original','2026-11-01');
insert into public.eyebible_replies(id,post_id,author_id,author,text) values('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','{}','reply');
insert into public.eyebible_reactions values('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
insert into public.personal_states(user_id,revision,payload) values
('00000000-0000-0000-0000-000000000002',1,'{"schemaVersion":1,"records":{"[\"note\",\"own\"]":{"id":"own","sharedPostId":"20000000-0000-0000-0000-000000000001","sharedGroupId":"10000000-0000-0000-0000-000000000001","authorId":"00000000-0000-0000-0000-000000000002","text":"original","reference":"","quote":"","private":false},"[\"note\",\"legacy\"]":{"id":"legacy","text":"original","reference":"","quote":"","private":false,"date":"2020-01-01"},"[\"note\",\"private\"]":{"id":"private","text":"original","private":true}}}'),
('00000000-0000-0000-0000-000000000001',1,'{"schemaVersion":1,"records":{"[\"note\",\"other\"]":{"id":"other","text":"original","private":false}}}');
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$declare d jsonb:='{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","expected_text":"original","text":"modified"}';begin
 begin perform public.group_edit_text(d);raise exception 'leader edited another author';exception when insufficient_privilege then null;end;
 begin perform public.group_edit_text(d||'{"reply_id":"30000000-0000-0000-0000-000000000001","expected_text":"reply"}');raise exception 'leader edited another reply';exception when insufficient_privilege then null;end;
end$$;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$declare d jsonb:='{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","expected_text":"original","text":"modified"}';begin
 perform public.group_edit_text(d);perform public.group_edit_text(d);
 begin perform public.group_edit_text(d||'{"text":"stale edit"}');raise exception 'stale edit accepted';exception when serialization_failure then null;end;
 begin perform public.group_edit_text(d||'{"text":"   "}');raise exception 'empty text accepted';exception when invalid_parameter_value then null;end;
 perform public.group_edit_text(d||'{"reply_id":"30000000-0000-0000-0000-000000000001","expected_text":"reply","text":"new reply"}');
end$$;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
do $$begin begin perform public.group_edit_text('{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","expected_text":"modified","text":"outsider"}');raise exception 'outsider edited';exception when insufficient_privilege then null;end;end$$;
reset role;
do $$begin
 if (select payload->'records'->'["note","own"]'->>'text' from public.personal_states where user_id='00000000-0000-0000-0000-000000000002') is distinct from 'modified' then raise exception 'personal copy not synced';end if;
 if (select payload->'records'->'["note","private"]'->>'text' from public.personal_states where user_id='00000000-0000-0000-0000-000000000002') is distinct from 'original' then raise exception 'private note changed';end if;
 if (select payload->'records'->'["note","other"]'->>'text' from public.personal_states where user_id='00000000-0000-0000-0000-000000000001') is distinct from 'original' then raise exception 'another owner changed';end if;
 if (select payload->'records'->'["note","legacy"]'->>'text' from public.personal_states where user_id='00000000-0000-0000-0000-000000000002') is distinct from 'original' then raise exception 'unlinked legacy note wrongly inferred';end if;
 if (select revision from public.personal_states where user_id='00000000-0000-0000-0000-000000000002')<>2 then raise exception 'retry changed revision twice';end if;
 if not exists(select 1 from public.eyebible_posts where text='modified' and created_at='2026-11-01' and id='20000000-0000-0000-0000-000000000001') then raise exception 'post identity/date changed';end if;
 if (select count(*) from public.eyebible_reactions)<>1 then raise exception 'reaction lost';end if;
 if not exists(select 1 from public.eyebible_replies where text='new reply') then raise exception 'reply not edited';end if;
end$$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$declare d jsonb:='{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","note_id":"legacy","expected_text":"modified","text":"should not commit"}';begin
 begin perform public.group_edit_text(d);raise exception 'changed selected source silently skipped';exception when serialization_failure then null;end;
 begin perform public.group_edit_text(d||'{"note_id":"private","expected_text":"original"}');raise exception 'selected private source accepted';exception when insufficient_privilege or serialization_failure then null;end;
end$$;
reset role;
do $$begin if (select text from public.eyebible_posts where id='20000000-0000-0000-0000-000000000001')<>'modified' then raise exception 'source conflict partially committed';end if;end$$;
update public.personal_states set payload=jsonb_set(payload,array['records','["note","legacy"]'],(payload->'records'->'["note","legacy"]')||'{"text":"modified","sharedPostId":"20000000-0000-0000-0000-000000000099","sharedGroupId":"10000000-0000-0000-0000-000000000001"}') where user_id='00000000-0000-0000-0000-000000000002';
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$begin begin perform public.group_edit_text('{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","note_id":"legacy","expected_text":"modified","text":"reassigned"}');raise exception 'source relinked after concurrent change';exception when serialization_failure then null;end;end$$;
reset role;
update public.eyebible_posts set deleted_at=now() where id='20000000-0000-0000-0000-000000000001';
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$begin begin perform public.group_edit_text('{"group_id":"10000000-0000-0000-0000-000000000001","post_id":"20000000-0000-0000-0000-000000000001","expected_text":"modified","text":"resurrected"}');raise exception 'deleted post edited';exception when insufficient_privilege then null;end;end$$;
set local role anon;
do $$begin begin perform public.group_edit_text('{}');raise exception 'anonymous execute allowed';exception when insufficient_privilege then null;end;end$$;
reset role;
rollback;
