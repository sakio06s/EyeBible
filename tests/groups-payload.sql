-- Fixture-only photo/unseen amplification regression, disposable DB only.
reset role;
update public.eyebible_members set image='data:image/png;base64,'||repeat('A',4000) where user_id='00000000-0000-0000-0000-000000000001';
insert into public.eyebible_posts(id,group_id,author_id,author,text)
select '88888888-8888-4888-8888-888888888888',id,owner_id,'{"name":"Alice","image":""}','busy thread' from public.eyebible_groups where owner_id='00000000-0000-0000-0000-000000000001' on conflict do nothing;
insert into public.eyebible_replies(id,post_id,author_id,author,text)
select ('88888888-8888-4888-8888-'||lpad(n::text,12,'0'))::uuid,'88888888-8888-4888-8888-888888888888','00000000-0000-0000-0000-000000000001','{"name":"Alice","image":""}','busy reply '||n from generate_series(1,200)n on conflict do nothing;
set role authenticated;
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $$ declare r jsonb:=public.group_read('recent');p jsonb;begin
 select value into p from jsonb_array_elements(r->'posts') where value->>'id'='88888888-8888-4888-8888-888888888888';
 if octet_length((p->'replies')::text)>150000 then raise exception 'Full avatar repeated across reply payload';end if;
 if jsonb_array_length(p->'unseen')>101 then raise exception 'Unseen identifiers include unloaded reply pages';end if;
 if jsonb_array_length(p->'replies')<>100 or (p->>'replyCount')::int<>200 then raise exception 'Reply page count lost';end if;
end $$;
reset role;
