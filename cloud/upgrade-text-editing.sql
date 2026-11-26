-- Additive, re-runnable. Only authors may edit; dates, reactions and replies are preserved.
begin;
create or replace function public.group_edit_targets(p_data jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid();gid uuid;targets jsonb;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>80000 then raise exception 'Invalid request' using errcode='22023';end if;
 gid:=(p_data->>'group_id')::uuid;
 if not exists(select 1 from public.eyebible_members where user_id=actor and group_id=gid) then raise exception 'Membership required' using errcode='42501';end if;
 if p_data->>'mode'='capabilities' then return jsonb_build_object('editing_version',2);end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'text',text,'createdAt',created_at) order by created_at,id),'[]'::jsonb) into targets
 from public.eyebible_posts where group_id=gid and author_id=actor and deleted_at is null and
 (case when coalesce(p_data->>'post_id','')<>'' then id=(p_data->>'post_id')::uuid else
 text=p_data->>'text' and reference=coalesce(p_data->>'reference','') and quote=coalesce(p_data->>'quote','') end);
 return targets;
end $$;
create or replace function public.group_edit_text(p_data jsonb)
returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare actor uuid:=auth.uid();gid uuid;pid uuid;rid uuid;body text;expected text;p public.eyebible_posts;r public.eyebible_replies;
 saved public.personal_states;rec record;next_records jsonb;notes jsonb:='[]';changed boolean:=false;value jsonb;source jsonb;source_count integer;sync_enabled boolean;source_expected text;note_expected text;
begin
 if actor is null then raise exception 'Authentication required' using errcode='42501';end if;
 if jsonb_typeof(p_data) is distinct from 'object' or octet_length(p_data::text)>700000 or jsonb_typeof(p_data->'text') is distinct from 'string' or jsonb_typeof(p_data->'expected_text') is distinct from 'string' then raise exception 'Invalid edit' using errcode='22023';end if;
 gid:=(p_data->>'group_id')::uuid;pid:=(p_data->>'post_id')::uuid;rid:=nullif(p_data->>'reply_id','')::uuid;
 body:=trim(p_data->>'text');expected:=p_data->>'expected_text';sync_enabled:=coalesce((p_data->>'sync_notes')::boolean,true);source_expected:=coalesce(p_data->>'expected_note_text',expected);
 if length(source_expected)>10000 then raise exception 'Invalid source text' using errcode='22023';end if;
 if length(body) not between 1 and (case when rid is null then 10000 else 2000 end) or length(expected)>10000 then raise exception 'Invalid text length' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 perform 1 from public.eyebible_groups where id=gid for update;
 if not exists(select 1 from public.eyebible_members where user_id=actor and group_id=gid) then raise exception 'Membership required' using errcode='42501';end if;
 select * into p from public.eyebible_posts where id=pid and group_id=gid and deleted_at is null for update;
 if not found then raise exception 'Post unavailable' using errcode='42501';end if;
 if rid is not null then
  select * into r from public.eyebible_replies where id=rid and post_id=pid and deleted_at is null for update;
  if not found or r.author_id is distinct from actor then raise exception 'Author required' using errcode='42501';end if;
  if r.text<>expected and r.text<>body then raise exception 'Text changed; reopen editor' using errcode='40001';end if;
  update public.eyebible_replies set text=body where id=rid;
 else
  if p.author_id is distinct from actor then raise exception 'Author required' using errcode='42501';end if;
  if p.text<>expected and p.text<>body then raise exception 'Text changed; reopen editor' using errcode='40001';end if;
  if sync_enabled then
  select * into saved from public.personal_states where user_id=actor for update;
  if found then
   next_records:=saved.payload->'records';
   if p_data->>'note_id' is not null then
    select count(*) into source_count from jsonb_each(next_records) x where x.key like '["note",%' and x.value->>'id'=p_data->>'note_id';
    if source_count>1 then raise exception 'Ambiguous personal note' using errcode='40001';end if;
    select x.value into source from jsonb_each(next_records) x where x.key like '["note",%' and x.value->>'id'=p_data->>'note_id';
    if found then
     if source->'private'='true'::jsonb or (source->>'authorId' is not null and source->>'authorId'<>actor::text) then raise exception 'Personal note owner required' using errcode='42501';end if;
     if (source->>'sharedPostId' is not null and source->>'sharedPostId'<>pid::text)
        or (source->>'sharedGroupId' is not null and source->>'sharedGroupId'<>gid::text)
        or coalesce(source->>'reference','')<>p.reference or coalesce(source->>'quote','')<>p.quote
        or (source->>'text' is distinct from source_expected and source->>'text' is distinct from body) then
      raise exception 'Personal note changed; reopen editor' using errcode='40001';
     end if;
    end if;
   end if;
   for rec in select * from jsonb_each(next_records) x where x.key like '["note",%' and x.value->'private' is distinct from 'true'::jsonb and (x.value->>'authorId' is null or x.value->>'authorId'=actor::text) loop
    if (rec.value->>'sharedPostId'=pid::text and rec.value->>'sharedGroupId'=gid::text)
       or (p_data->>'note_id' is not null and rec.value->>'id'=p_data->>'note_id')
 then
     note_expected:=coalesce(p_data->'expected_notes'->>(rec.value->>'id'),case when rec.value->>'id'=p_data->>'note_id' then source_expected else expected end);
     if rec.value->>'text' is distinct from note_expected and rec.value->>'text' is distinct from body then raise exception 'Personal note changed; reopen editor' using errcode='40001';end if;
     value:=rec.value||jsonb_build_object('text',body,'sharedPostId',pid,'sharedGroupId',gid);
     next_records:=jsonb_set(next_records,array[rec.key],value);notes:=notes||jsonb_build_array(value);changed:=changed or value<>rec.value;
    end if;
   end loop;
   if changed then update public.personal_states set payload=jsonb_set(saved.payload,'{records}',next_records),revision=revision+1,updated_at=now() where user_id=actor;end if;
  end if;
  end if;
  update public.eyebible_posts set text=body where id=pid;
 end if;
 return jsonb_build_object('ok',true,'notes',notes);
end $$;
revoke all on function public.group_edit_text(jsonb),public.group_edit_targets(jsonb) from public,anon;
grant execute on function public.group_edit_text(jsonb),public.group_edit_targets(jsonb) to authenticated;
commit;
notify pgrst,'reload schema';
