alter table public.sales_items add column if not exists costing_status text not null default 'PENDING' check (costing_status in ('PENDING','PROCESSED','MISSING_COST','ERROR'));

create unique index if not exists inventory_sale_usage_once_idx on public.inventory_movements(sales_item_id, ingredient_id) where movement_type='SALE_USAGE' and sales_item_id is not null;

create or replace view public.inventory_summary with (security_invoker=true) as
select i.id as ingredient_id, i.ingredient_code, i.name_th, i.name_en, i.base_unit_id,
       coalesce(sum(m.quantity_base_unit),0)::numeric(14,4) as current_quantity,
       coalesce(sum(m.total_cost),0)::numeric(14,2) as current_value,
       case when coalesce(sum(m.quantity_base_unit),0) > 0 then round((coalesce(sum(m.total_cost),0)/sum(m.quantity_base_unit))::numeric,4) else null end as weighted_avg_cost,
       i.minimum_stock_level,
       (coalesce(sum(m.quantity_base_unit),0) <= i.minimum_stock_level) as is_low_stock
from public.ingredients i left join public.inventory_movements m on m.ingredient_id=i.id
group by i.id,i.ingredient_code,i.name_th,i.name_en,i.base_unit_id,i.minimum_stock_level;
grant select on public.inventory_summary to authenticated;
revoke all on public.inventory_summary from anon;

create or replace function private.to_base_quantity(p_ingredient_id uuid,p_quantity numeric,p_from_unit_id uuid)
returns numeric language plpgsql security definer set search_path=public,private as $$
declare v_base uuid;v_factor numeric;begin
 select base_unit_id into v_base from public.ingredients where id=p_ingredient_id;
 if v_base is null then raise exception 'Ingredient base unit not found'; end if;
 if p_from_unit_id=v_base then return p_quantity; end if;
 select conversion_factor into v_factor from public.unit_conversions where from_unit_id=p_from_unit_id and to_unit_id=v_base and is_active=true and (ingredient_id=p_ingredient_id or ingredient_id is null) order by (ingredient_id is not null) desc limit 1;
 if v_factor is null then raise exception 'No unit conversion configured for ingredient %',p_ingredient_id; end if;
 return p_quantity*v_factor;end $$;
revoke all on function private.to_base_quantity(uuid,numeric,uuid) from public,anon,authenticated;

create or replace function public.record_opening_stock(p_ingredient_id uuid,p_quantity_base numeric,p_total_cost numeric,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,private as $$
declare v_user uuid:=auth.uid();v_role public.user_role;v_id uuid;begin
 if v_user is null then raise exception 'Authentication required';end if;
 select role into v_role from public.profiles where id=v_user and is_active=true;
 if v_role not in ('OWNER','MANAGER') then raise exception 'Owner or manager permission required';end if;
 if p_quantity_base<=0 or p_total_cost<0 then raise exception 'Opening quantity must be positive and cost non-negative';end if;
 if not exists(select 1 from public.ingredients where id=p_ingredient_id and is_active=true) then raise exception 'Active ingredient not found';end if;
 if exists(select 1 from public.inventory_movements where ingredient_id=p_ingredient_id) then raise exception 'Opening stock can only be recorded before other movements exist for this ingredient';end if;
 insert into public.inventory_movements(ingredient_id,movement_type,quantity_base_unit,unit_cost,total_cost,reference_type,occurred_at,notes,created_by)
 values(p_ingredient_id,'OPENING',p_quantity_base,case when p_quantity_base>0 then round(p_total_cost/p_quantity_base,4) end,p_total_cost,'OPENING_STOCK',now(),p_notes,v_user) returning id into v_id;
 insert into public.audit_logs(user_id,action,entity_type,entity_id,after_data) values(v_user,'OPENING_STOCK_RECORDED','inventory_movements',v_id,jsonb_build_object('ingredient_id',p_ingredient_id,'quantity',p_quantity_base,'total_cost',p_total_cost));return v_id;end $$;
revoke all on function public.record_opening_stock(uuid,numeric,numeric,text) from public,anon;
grant execute on function public.record_opening_stock(uuid,numeric,numeric,text) to authenticated;

create or replace function public.process_pending_sales_inventory(p_sales_item_ids uuid[] default null)
returns jsonb language plpgsql security definer set search_path=public,private as $$
declare v_user uuid:=auth.uid();v_role public.user_role;s record;ri record;v_base_qty numeric;v_stock_qty numeric;v_stock_value numeric;v_avg numeric;v_total_cost numeric;v_line_cost numeric;v_missing boolean;v_processed int:=0;v_missing_count int:=0;v_errors int:=0;begin
 if v_user is null then raise exception 'Authentication required';end if;select role into v_role from public.profiles where id=v_user and is_active=true;if v_role not in ('OWNER','MANAGER') then raise exception 'Owner or manager permission required';end if;
 for s in select si.*,r.yield_quantity from public.sales_items si join public.recipes r on r.id=si.recipe_id where si.mapping_status='MATCHED' and si.recipe_id is not null and si.costing_status in ('PENDING','MISSING_COST','ERROR') and (p_sales_item_ids is null or si.id=any(p_sales_item_ids)) order by si.created_at,si.id loop
  begin
   if exists(select 1 from public.inventory_movements where sales_item_id=s.id and movement_type='SALE_USAGE') then update public.sales_items set costing_status='PROCESSED' where id=s.id;continue;end if;
   v_missing:=false;v_total_cost:=0;
   for ri in select x.*,ing.track_stock from public.recipe_items x join public.ingredients ing on ing.id=x.ingredient_id where x.recipe_id=s.recipe_id order by x.display_order,x.id loop
    v_base_qty:=private.to_base_quantity(ri.ingredient_id,ri.quantity,ri.unit_id)*s.quantity/nullif(s.yield_quantity,0)*(1+coalesce(ri.wastage_percentage,0)/100);
    select coalesce(sum(quantity_base_unit),0),coalesce(sum(total_cost),0) into v_stock_qty,v_stock_value from public.inventory_movements where ingredient_id=ri.ingredient_id;
    if v_stock_qty<=0 or v_stock_value<=0 then v_missing:=true;exit;end if;v_avg:=v_stock_value/v_stock_qty;v_total_cost:=v_total_cost+(v_base_qty*v_avg);
   end loop;
   if v_missing then update public.sales_items set costing_status='MISSING_COST' where id=s.id;v_missing_count:=v_missing_count+1;continue;end if;
   for ri in select x.*,ing.track_stock from public.recipe_items x join public.ingredients ing on ing.id=x.ingredient_id where x.recipe_id=s.recipe_id order by x.display_order,x.id loop
    v_base_qty:=private.to_base_quantity(ri.ingredient_id,ri.quantity,ri.unit_id)*s.quantity/nullif(s.yield_quantity,0)*(1+coalesce(ri.wastage_percentage,0)/100);
    select coalesce(sum(quantity_base_unit),0),coalesce(sum(total_cost),0) into v_stock_qty,v_stock_value from public.inventory_movements where ingredient_id=ri.ingredient_id;v_avg:=v_stock_value/nullif(v_stock_qty,0);v_line_cost:=v_base_qty*v_avg;
    if ri.track_stock then insert into public.inventory_movements(ingredient_id,movement_type,quantity_base_unit,unit_cost,total_cost,reference_type,reference_id,sales_item_id,occurred_at,notes,created_by) values(ri.ingredient_id,'SALE_USAGE',-v_base_qty,round(v_avg,4),-round(v_line_cost,2),'SALES_ITEM',s.id,s.id,coalesce((select sold_at from public.sales_transactions where id=s.sales_transaction_id),now()),'Automatic recipe usage',v_user);end if;
   end loop;
   update public.sales_items set unit_cost_snapshot=round(v_total_cost/nullif(s.quantity,0),4),total_cost_snapshot=round(v_total_cost,2),costing_status='PROCESSED' where id=s.id;v_processed:=v_processed+1;
  exception when others then update public.sales_items set costing_status='ERROR' where id=s.id;v_errors:=v_errors+1;end;
 end loop;
 insert into public.audit_logs(user_id,action,entity_type,after_data) values(v_user,'SALES_INVENTORY_PROCESSED','sales_items',jsonb_build_object('processed',v_processed,'missing_cost',v_missing_count,'errors',v_errors));return jsonb_build_object('processed',v_processed,'missing_cost',v_missing_count,'errors',v_errors);end $$;
revoke all on function public.process_pending_sales_inventory(uuid[]) from public,anon;
grant execute on function public.process_pending_sales_inventory(uuid[]) to authenticated;
