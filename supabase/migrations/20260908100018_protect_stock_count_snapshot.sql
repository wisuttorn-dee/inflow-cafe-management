create or replace function private.protect_stock_count_snapshot()
returns trigger language plpgsql security invoker set search_path=''
as $$
begin
  if (select private.current_user_role())='STAFF' then
    if new.stock_count_id is distinct from old.stock_count_id
       or new.ingredient_id is distinct from old.ingredient_id
       or new.expected_quantity is distinct from old.expected_quantity
       or new.variance_quantity is distinct from old.variance_quantity
       or new.variance_percentage is distinct from old.variance_percentage
       or new.unit_id is distinct from old.unit_id then
      raise exception 'STAFF may update actual_quantity only';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_stock_count_snapshot on public.stock_count_items;
create trigger trg_protect_stock_count_snapshot
before update on public.stock_count_items
for each row execute function private.protect_stock_count_snapshot();
