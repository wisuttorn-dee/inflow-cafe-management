create table if not exists public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  count_date date not null default current_date,
  status text not null default 'DRAFT' check (status in ('DRAFT','COMPLETED','CANCELLED')),
  started_by uuid not null references public.profiles(id),
  completed_by uuid null references public.profiles(id),
  started_at timestamptz not null default now(),
  completed_at timestamptz null,
  notes text null,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_count_items (
  id uuid primary key default gen_random_uuid(),
  stock_count_id uuid not null references public.stock_counts(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  expected_quantity numeric(14,4) not null default 0,
  actual_quantity numeric(14,4) null,
  variance_quantity numeric(14,4) null,
  variance_percentage numeric(14,4) null,
  unit_id uuid not null references public.units(id),
  created_at timestamptz not null default now(),
  unique(stock_count_id, ingredient_id)
);

create table if not exists public.waste_records (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients(id),
  quantity numeric(14,4) not null check (quantity > 0),
  unit_id uuid not null references public.units(id),
  quantity_base_unit numeric(14,4) not null check (quantity_base_unit > 0),
  reason_code text not null check (reason_code in ('EXPIRED','SPILLAGE','PREPARATION_ERROR','QUALITY_ISSUE','DAMAGED','STAFF_DRINK','COMPLIMENTARY','OTHER')),
  notes text null,
  occurred_at timestamptz not null default now(),
  recorded_by uuid not null references public.profiles(id),
  inventory_movement_id uuid unique null references public.inventory_movements(id),
  created_at timestamptz not null default now()
);

create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_th text not null,
  name_en text not null,
  is_inventory_related boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  expense_date date not null default current_date,
  category_id uuid not null references public.expense_categories(id),
  supplier_id uuid null references public.suppliers(id),
  description text not null,
  amount numeric(14,2) not null check (amount > 0),
  payment_method text null,
  reference_no text null,
  receipt_url text null,
  related_purchase_id uuid null references public.purchases(id),
  notes text null,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','VOID')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.expense_categories(code,name_th,name_en,is_inventory_related) values
('INGREDIENTS','วัตถุดิบ','Ingredients',true),('PACKAGING','บรรจุภัณฑ์','Packaging',true),('UTILITIES','ค่าน้ำ ค่าไฟ และสาธารณูปโภค','Utilities',false),('STAFF','ค่าใช้จ่ายพนักงาน','Staff',false),('MARKETING','การตลาด','Marketing',false),('CLEANING','ทำความสะอาด','Cleaning',false),('EQUIPMENT','อุปกรณ์','Equipment',false),('REPAIR','ซ่อมบำรุง','Repair',false),('TRANSPORTATION','ขนส่ง','Transportation',false),('PLATFORM_FEES','ค่าธรรมเนียมแพลตฟอร์ม','Platform fees',false),('BANK_FEES','ค่าธรรมเนียมธนาคาร','Bank fees',false),('OTHER','อื่น ๆ','Other',false)
on conflict (code) do nothing;

create index if not exists stock_counts_status_idx on public.stock_counts(status);
create index if not exists stock_count_items_count_idx on public.stock_count_items(stock_count_id);
create index if not exists waste_records_occurred_at_idx on public.waste_records(occurred_at desc);
create index if not exists waste_records_ingredient_idx on public.waste_records(ingredient_id);
create index if not exists expenses_date_idx on public.expenses(expense_date desc);
create index if not exists expenses_category_idx on public.expenses(category_id);
create index if not exists expenses_created_by_idx on public.expenses(created_by);

alter table public.stock_counts enable row level security;
alter table public.stock_count_items enable row level security;
alter table public.waste_records enable row level security;
alter table public.expense_categories enable row level security;
alter table public.expenses enable row level security;

revoke all on public.stock_counts,public.stock_count_items,public.waste_records,public.expense_categories,public.expenses from anon,public;
grant select,insert,update on public.stock_counts,public.stock_count_items to authenticated;
grant select,insert on public.waste_records to authenticated;
grant select,insert,update on public.expense_categories to authenticated;
grant select,insert,update on public.expenses to authenticated;

create policy stock_counts_read on public.stock_counts for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy stock_counts_insert on public.stock_counts for insert to authenticated with check (started_by=(select auth.uid()) and (select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy stock_counts_update_management on public.stock_counts for update to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER')) with check ((select private.current_user_role()) in ('OWNER','MANAGER'));
create policy stock_count_items_read on public.stock_count_items for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy stock_count_items_insert on public.stock_count_items for insert to authenticated with check ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy stock_count_items_update on public.stock_count_items for update to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER') or ((select private.current_user_role())='STAFF' and exists(select 1 from public.stock_counts sc where sc.id=stock_count_id and sc.status='DRAFT'))) with check ((select private.current_user_role()) in ('OWNER','MANAGER') or ((select private.current_user_role())='STAFF' and exists(select 1 from public.stock_counts sc where sc.id=stock_count_id and sc.status='DRAFT')));
create policy waste_read on public.waste_records for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy waste_insert on public.waste_records for insert to authenticated with check (recorded_by=(select auth.uid()) and (select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy expense_categories_read on public.expense_categories for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy expense_categories_insert_management on public.expense_categories for insert to authenticated with check ((select private.current_user_role()) in ('OWNER','MANAGER'));
create policy expense_categories_update_management on public.expense_categories for update to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER')) with check ((select private.current_user_role()) in ('OWNER','MANAGER'));
create policy expenses_read on public.expenses for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER') or created_by=(select auth.uid()));
create policy expenses_insert on public.expenses for insert to authenticated with check (created_by=(select auth.uid()) and (select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
create policy expenses_update_management on public.expenses for update to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER')) with check ((select private.current_user_role()) in ('OWNER','MANAGER'));

create or replace function private.append_audit(p_action text,p_entity_type text,p_entity_id uuid,p_after_data jsonb default null) returns void language plpgsql security definer set search_path='' as $$ begin insert into public.audit_logs(user_id,action,entity_type,entity_id,after_data) values(auth.uid(),p_action,p_entity_type,p_entity_id,p_after_data); end; $$;
revoke execute on function private.append_audit(text,text,uuid,jsonb) from public,anon;
grant execute on function private.append_audit(text,text,uuid,jsonb) to authenticated;

create or replace function public.create_stock_count(p_count_date date default current_date,p_notes text default null) returns uuid language plpgsql security invoker set search_path='' as $$ declare v_id uuid;v_user uuid:=auth.uid(); begin if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER','STAFF') then raise exception 'Active authenticated user required';end if;if exists(select 1 from public.stock_counts where status='DRAFT') then raise exception 'A draft stock count already exists';end if;insert into public.stock_counts(count_date,started_by,notes) values(coalesce(p_count_date,current_date),v_user,p_notes) returning id into v_id;insert into public.stock_count_items(stock_count_id,ingredient_id,expected_quantity,unit_id) select v_id,i.id,coalesce(s.current_quantity,0),i.base_unit_id from public.ingredients i left join public.inventory_summary s on s.ingredient_id=i.id where i.is_active=true and i.track_stock=true;return v_id;end; $$;
revoke execute on function public.create_stock_count(date,text) from public,anon;grant execute on function public.create_stock_count(date,text) to authenticated;

create or replace function public.finalize_stock_count(p_stock_count_id uuid) returns jsonb language plpgsql security invoker set search_path='' as $$ declare v_user uuid:=auth.uid();v_adjusted integer:=0;r record;v_cost numeric(14,4);v_variance numeric(14,4);v_pct numeric(14,4); begin if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER') then raise exception 'OWNER or MANAGER required';end if;if not exists(select 1 from public.stock_counts where id=p_stock_count_id and status='DRAFT') then raise exception 'Draft stock count not found';end if;if exists(select 1 from public.stock_count_items where stock_count_id=p_stock_count_id and actual_quantity is null) then raise exception 'All actual quantities are required before finalising';end if;for r in select * from public.stock_count_items where stock_count_id=p_stock_count_id loop v_variance:=r.actual_quantity-r.expected_quantity;v_pct:=case when r.expected_quantity=0 then null else round((v_variance/r.expected_quantity*100)::numeric,4) end;update public.stock_count_items set variance_quantity=v_variance,variance_percentage=v_pct where id=r.id;if v_variance<>0 then select weighted_avg_cost into v_cost from public.inventory_summary where ingredient_id=r.ingredient_id;insert into public.inventory_movements(ingredient_id,movement_type,quantity_base_unit,unit_cost,total_cost,reference_type,reference_id,stock_count_id,occurred_at,notes,created_by) values(r.ingredient_id,'STOCK_COUNT_ADJUSTMENT',v_variance,v_cost,case when v_cost is null then null else round((v_variance*v_cost)::numeric,2) end,'stock_count',p_stock_count_id,p_stock_count_id,now(),'Physical stock count adjustment',v_user);v_adjusted:=v_adjusted+1;end if;end loop;update public.stock_counts set status='COMPLETED',completed_by=v_user,completed_at=now() where id=p_stock_count_id;perform private.append_audit('STOCK_COUNT_COMPLETED','stock_counts',p_stock_count_id,jsonb_build_object('adjusted_items',v_adjusted));return jsonb_build_object('stock_count_id',p_stock_count_id,'adjusted_items',v_adjusted,'status','COMPLETED');end; $$;
revoke execute on function public.finalize_stock_count(uuid) from public,anon;grant execute on function public.finalize_stock_count(uuid) to authenticated;

create or replace function public.record_waste(p_ingredient_id uuid,p_quantity numeric,p_unit_id uuid,p_reason_code text,p_notes text default null,p_occurred_at timestamptz default now()) returns uuid language plpgsql security invoker set search_path='' as $$ declare v_user uuid:=auth.uid();v_base numeric(14,4);v_cost numeric(14,4);v_move uuid;v_waste uuid; begin if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER','STAFF') then raise exception 'Active authenticated user required';end if;if p_quantity is null or p_quantity<=0 then raise exception 'Waste quantity must be greater than zero';end if;if p_reason_code not in ('EXPIRED','SPILLAGE','PREPARATION_ERROR','QUALITY_ISSUE','DAMAGED','STAFF_DRINK','COMPLIMENTARY','OTHER') then raise exception 'Invalid waste reason';end if;v_base:=private.to_base_quantity(p_ingredient_id,p_quantity,p_unit_id);select weighted_avg_cost into v_cost from public.inventory_summary where ingredient_id=p_ingredient_id;insert into public.inventory_movements(ingredient_id,movement_type,quantity_base_unit,unit_cost,total_cost,reference_type,occurred_at,notes,created_by) values(p_ingredient_id,'WASTE',-v_base,v_cost,case when v_cost is null then null else round((-v_base*v_cost)::numeric,2) end,'waste',coalesce(p_occurred_at,now()),p_notes,v_user) returning id into v_move;insert into public.waste_records(ingredient_id,quantity,unit_id,quantity_base_unit,reason_code,notes,occurred_at,recorded_by,inventory_movement_id) values(p_ingredient_id,p_quantity,p_unit_id,v_base,p_reason_code,p_notes,coalesce(p_occurred_at,now()),v_user,v_move) returning id into v_waste;update public.inventory_movements set reference_id=v_waste where id=v_move;return v_waste;end; $$;
revoke execute on function public.record_waste(uuid,numeric,uuid,text,text,timestamptz) from public,anon;grant execute on function public.record_waste(uuid,numeric,uuid,text,text,timestamptz) to authenticated;

create or replace function public.record_expense(p_expense_date date,p_category_id uuid,p_description text,p_amount numeric,p_payment_method text default null,p_supplier_id uuid default null,p_reference_no text default null,p_notes text default null) returns uuid language plpgsql security invoker set search_path='' as $$ declare v_user uuid:=auth.uid();v_id uuid; begin if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER','STAFF') then raise exception 'Active authenticated user required';end if;if p_amount is null or p_amount<=0 then raise exception 'Expense amount must be greater than zero';end if;insert into public.expenses(expense_date,category_id,supplier_id,description,amount,payment_method,reference_no,notes,created_by) values(coalesce(p_expense_date,current_date),p_category_id,p_supplier_id,trim(p_description),p_amount,nullif(trim(p_payment_method),''),nullif(trim(p_reference_no),''),p_notes,v_user) returning id into v_id;return v_id;end; $$;
revoke execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text) from public,anon;grant execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text) to authenticated;

create or replace function public.void_expense(p_expense_id uuid,p_reason text) returns void language plpgsql security invoker set search_path='' as $$ begin if auth.uid() is null or (select private.current_user_role()) not in ('OWNER','MANAGER') then raise exception 'OWNER or MANAGER required';end if;update public.expenses set status='VOID',notes=concat_ws(E'\n',notes,'VOID: '||coalesce(nullif(trim(p_reason),''),'No reason provided')),updated_at=now() where id=p_expense_id and status='ACTIVE';if not found then raise exception 'Active expense not found';end if;perform private.append_audit('EXPENSE_VOIDED','expenses',p_expense_id,jsonb_build_object('reason',p_reason));end; $$;
revoke execute on function public.void_expense(uuid,text) from public,anon;grant execute on function public.void_expense(uuid,text) to authenticated;

create or replace function public.get_management_summary(p_month date default current_date) returns jsonb language plpgsql security invoker set search_path='' as $$ declare v_start date:=date_trunc('month',coalesce(p_month,current_date))::date;v_end date;v_sales numeric(14,2);v_cogs numeric(14,2);v_exp numeric(14,2);v_incomplete integer;v_gp numeric(14,2);v_op numeric(14,2);v_margin numeric(14,4); begin if auth.uid() is null or (select private.current_user_role()) not in ('OWNER','MANAGER') then raise exception 'OWNER or MANAGER required';end if;v_end:=(v_start+interval '1 month')::date;select coalesce(sum(net_amount),0) into v_sales from public.sales_transactions where status<>'REVERSED' and sales_date>=v_start and sales_date<v_end;select coalesce(sum(si.total_cost_snapshot),0),count(*) filter(where si.costing_status<>'PROCESSED') into v_cogs,v_incomplete from public.sales_items si join public.sales_transactions st on st.id=si.sales_transaction_id where st.status<>'REVERSED' and st.sales_date>=v_start and st.sales_date<v_end;select coalesce(sum(amount),0) into v_exp from public.expenses where status='ACTIVE' and expense_date>=v_start and expense_date<v_end;v_gp:=v_sales-v_cogs;v_op:=v_gp-v_exp;v_margin:=case when v_sales=0 then 0 else round((v_gp/v_sales*100)::numeric,4) end;return jsonb_build_object('period_start',v_start,'period_end_exclusive',v_end,'net_sales',v_sales,'cogs',v_cogs,'gross_profit',v_gp,'gross_margin_pct',v_margin,'operating_expenses',v_exp,'operating_profit',v_op,'incomplete_cogs_rows',v_incomplete);end; $$;
revoke execute on function public.get_management_summary(date) from public,anon;grant execute on function public.get_management_summary(date) to authenticated;

alter view public.inventory_summary set (security_invoker=true);
revoke all on public.inventory_summary from anon,public;
grant select on public.inventory_summary to authenticated;
