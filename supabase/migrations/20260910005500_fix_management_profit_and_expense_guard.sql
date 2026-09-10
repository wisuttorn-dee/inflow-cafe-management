create or replace function public.record_expense(
  p_expense_date date,
  p_category_id uuid,
  p_description text,
  p_amount numeric,
  p_payment_method text default null,
  p_supplier_id uuid default null,
  p_reference_no text default null,
  p_notes text default null,
  p_receipt_url text default null
) returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
begin
  if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER','STAFF') then
    raise exception 'Active authenticated user required';
  end if;
  if p_amount is null or p_amount<=0 then
    raise exception 'Expense amount must be greater than zero';
  end if;
  if nullif(trim(p_description),'') is null then
    raise exception 'Expense description is required';
  end if;
  if not exists (
    select 1 from public.expense_categories
    where id=p_category_id and is_active=true and is_inventory_related=false
  ) then
    raise exception 'Inventory-related expenses must be recorded through purchasing';
  end if;
  if p_receipt_url is not null and split_part(p_receipt_url,'/',1)<>v_user::text then
    raise exception 'Receipt path must belong to the current user';
  end if;
  insert into public.expenses(expense_date,category_id,supplier_id,description,amount,payment_method,reference_no,receipt_url,notes,created_by)
  values(coalesce(p_expense_date,current_date),p_category_id,p_supplier_id,trim(p_description),p_amount,nullif(trim(p_payment_method),''),nullif(trim(p_reference_no),''),nullif(trim(p_receipt_url),''),p_notes,v_user)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text,text) from public,anon;
grant execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text,text) to authenticated;

create or replace function public.record_expense(
  p_expense_date date,
  p_category_id uuid,
  p_description text,
  p_amount numeric,
  p_payment_method text default null,
  p_supplier_id uuid default null,
  p_reference_no text default null,
  p_notes text default null
) returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
begin
  if v_user is null or (select private.current_user_role()) not in ('OWNER','MANAGER','STAFF') then
    raise exception 'Active authenticated user required';
  end if;
  if p_amount is null or p_amount<=0 then
    raise exception 'Expense amount must be greater than zero';
  end if;
  if nullif(trim(p_description),'') is null then
    raise exception 'Expense description is required';
  end if;
  if not exists (
    select 1 from public.expense_categories
    where id=p_category_id and is_active=true and is_inventory_related=false
  ) then
    raise exception 'Inventory-related expenses must be recorded through purchasing';
  end if;
  insert into public.expenses(expense_date,category_id,supplier_id,description,amount,payment_method,reference_no,notes,created_by)
  values(coalesce(p_expense_date,current_date),p_category_id,p_supplier_id,trim(p_description),p_amount,nullif(trim(p_payment_method),''),nullif(trim(p_reference_no),''),p_notes,v_user)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text) from public,anon;
grant execute on function public.record_expense(date,uuid,text,numeric,text,uuid,text,text) to authenticated;

create or replace function public.get_management_summary(p_month date default current_date)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $$
declare
  v_start date:=date_trunc('month',coalesce(p_month,current_date))::date;
  v_end date;
  v_sales numeric(14,2);
  v_costed_sales numeric(14,2);
  v_cogs numeric(14,2);
  v_exp numeric(14,2);
  v_incomplete integer;
  v_gp numeric(14,2);
  v_op numeric(14,2);
  v_margin numeric(14,4);
begin
  if auth.uid() is null or (select private.current_user_role()) not in ('OWNER','MANAGER') then
    raise exception 'OWNER or MANAGER required';
  end if;
  v_end:=(v_start+interval '1 month')::date;

  select coalesce(sum(net_amount),0)
  into v_sales
  from public.sales_transactions
  where status<>'REVERSED' and sales_date>=v_start and sales_date<v_end;

  select
    coalesce(sum(si.net_amount) filter(where si.costing_status='PROCESSED' and si.total_cost_snapshot is not null),0),
    coalesce(sum(si.total_cost_snapshot) filter(where si.costing_status='PROCESSED' and si.total_cost_snapshot is not null),0),
    count(*) filter(where si.costing_status<>'PROCESSED' or si.total_cost_snapshot is null)
  into v_costed_sales,v_cogs,v_incomplete
  from public.sales_items si
  join public.sales_transactions st on st.id=si.sales_transaction_id
  where st.status<>'REVERSED' and st.sales_date>=v_start and st.sales_date<v_end;

  select coalesce(sum(amount),0)
  into v_exp
  from public.expenses
  where status='ACTIVE' and expense_date>=v_start and expense_date<v_end;

  v_gp:=v_costed_sales-v_cogs;
  v_op:=v_gp-v_exp;
  v_margin:=case when v_costed_sales=0 then 0 else round((v_gp/v_costed_sales*100)::numeric,4) end;

  return jsonb_build_object(
    'period_start',v_start,
    'period_end_exclusive',v_end,
    'net_sales',v_sales,
    'costed_sales',v_costed_sales,
    'cogs',v_cogs,
    'gross_profit',v_gp,
    'gross_margin_pct',v_margin,
    'operating_expenses',v_exp,
    'operating_profit',v_op,
    'incomplete_cogs_rows',v_incomplete
  );
end;
$$;
revoke execute on function public.get_management_summary(date) from public,anon;
grant execute on function public.get_management_summary(date) to authenticated;
