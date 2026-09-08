create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_role public.user_role;
begin
  if exists(select 1 from public.profiles) then
    v_role := 'STAFF';
  else
    v_role := 'OWNER';
  end if;
  insert into public.profiles(id,full_name,display_name,role)
  values(
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1)),
    v_role
  )
  on conflict(id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public,anon,authenticated;
