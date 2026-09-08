create or replace function public.set_updated_at() returns trigger language plpgsql set search_path = public, pg_temp as $$ begin new.updated_at=now(); new.updated_by=coalesce(auth.uid(),new.updated_by); return new; end $$;
revoke all on function public.set_updated_at() from public, anon, authenticated;
