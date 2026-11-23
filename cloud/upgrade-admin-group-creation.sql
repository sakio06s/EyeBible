-- Run after the existing support/admin migration. Does not create or change admins.
begin;
do $check$
begin
 if to_regprocedure('public.eyebible_is_app_admin(uuid)') is null then
  raise exception 'Apply the existing support/admin migration first';
 end if;
end $check$;
create or replace function public.eyebible_guard_group_creation()
returns trigger language plpgsql security definer set search_path=pg_catalog,public as $guard$
begin
 -- Unauthenticated API clients have no table INSERT grant; trusted SQL maintenance
 -- has no auth.uid(). All authenticated application creates must be app admins.
 if auth.uid() is not null and not public.eyebible_is_app_admin(auth.uid()) then
  raise exception 'Group creation is not enabled' using errcode='42501';
 end if;
 return new;
end $guard$;
revoke all on function public.eyebible_guard_group_creation() from public,anon,authenticated;
drop trigger if exists eyebible_admin_group_creation on public.eyebible_groups;
create trigger eyebible_admin_group_creation before insert on public.eyebible_groups
for each row execute function public.eyebible_guard_group_creation();
create or replace function public.group_capabilities()
returns jsonb language sql stable security definer set search_path=pg_catalog,public as $cap$
 select jsonb_build_object('can_create_group',public.eyebible_is_app_admin(auth.uid()));
$cap$;
revoke all on function public.group_capabilities() from public,anon;
grant execute on function public.group_capabilities() to authenticated;
notify pgrst,'reload schema';
commit;
