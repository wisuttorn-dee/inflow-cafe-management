create or replace function private.to_base_quantity(p_ingredient_id uuid,p_quantity numeric,p_from_unit_id uuid)
returns numeric
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_base uuid;
  v_factor numeric;
begin
  select base_unit_id into v_base from public.ingredients where id=p_ingredient_id;
  if v_base is null then raise exception 'Ingredient base unit not found'; end if;
  if p_from_unit_id=v_base then return p_quantity; end if;

  select conversion_factor into v_factor
  from public.unit_conversions
  where from_unit_id=p_from_unit_id
    and to_unit_id=v_base
    and is_active=true
    and (ingredient_id=p_ingredient_id or ingredient_id is null)
  order by (ingredient_id is not null) desc
  limit 1;

  if v_factor is null then raise exception 'No unit conversion configured for ingredient %',p_ingredient_id; end if;
  return p_quantity*v_factor;
end;
$$;

revoke all on function private.to_base_quantity(uuid,numeric,uuid) from public,anon;
grant execute on function private.to_base_quantity(uuid,numeric,uuid) to authenticated;
