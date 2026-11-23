-- Isolated fixture only: with sequential scans disabled the matching activity index needs no sort.
do $$ declare gid uuid;plan jsonb;begin
 select group_id into gid from public.eyebible_members limit 1;
 perform set_config('enable_seqscan','off',true);
 execute format('explain (format json,costs false) select id from public.eyebible_posts where group_id=%L::uuid and deleted_at is null order by greatest(last_reply_at,created_at) desc,id desc limit 10',gid) into plan;
 if plan::text like '%"Node Type": "Sort"%' then raise exception 'Latest activity feed needs matching ordered index';end if;
end $$;
select 'PASS latest activity index supports ordered paging without a sort';
