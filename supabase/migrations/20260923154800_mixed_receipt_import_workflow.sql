-- Mixed receipt import: one receipt may contain inventory purchases and operating expenses.
create table if not exists public.receipt_imports (
  id uuid primary key default gen_random_uuid(),
  receipt_date date not null default current_date,
  supplier_id uuid references public.suppliers(id),
  payment_method text,
  reference_no text,
  receipt_url text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT','CONFIRMED','CANCELLED')),
  notes text,
  created_by uuid not null references public.profiles(id),
  confirmed_by uuid references public.profiles(id),
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.receipt_import_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_import_id uuid not null references public.receipt_imports(id) on delete cascade,
  item_name text not null,
  line_type text not null check (line_type in ('INVENTORY','EXPENSE','REVIEW')),
  quantity numeric not null default 1 check (quantity > 0),
  amount numeric not null check (amount > 0),
  ingredient_id uuid references public.ingredients(id),
  purchase_unit_id uuid references public.units(id),
  base_quantity numeric,
  expense_category_id uuid references public.expense_categories(id),
  notes text,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists receipt_imports_created_by_idx on public.receipt_imports(created_by);
create index if not exists receipt_imports_status_idx on public.receipt_imports(status,receipt_date desc);
create index if not exists receipt_import_lines_import_idx on public.receipt_import_lines(receipt_import_id,display_order);

alter table public.receipt_imports enable row level security;
alter table public.receipt_import_lines enable row level security;

drop policy if exists receipt_imports_read on public.receipt_imports;
create policy receipt_imports_read on public.receipt_imports
for select to authenticated
using (private.current_user_role() in ('OWNER','MANAGER') or created_by=auth.uid());

drop policy if exists receipt_imports_insert on public.receipt_imports;
create policy receipt_imports_insert on public.receipt_imports
for insert to authenticated
with check (created_by=auth.uid() and private.current_user_role() in ('OWNER','MANAGER','STAFF'));

drop policy if exists receipt_imports_update on public.receipt_imports;
create policy receipt_imports_update on public.receipt_imports
for update to authenticated
using (status='DRAFT' and (private.current_user_role() in ('OWNER','MANAGER') or created_by=auth.uid()))
with check (private.current_user_role() in ('OWNER','MANAGER') or created_by=auth.uid());

drop policy if exists receipt_imports_delete on public.receipt_imports;
create policy receipt_imports_delete on public.receipt_imports
for delete to authenticated
using (status='DRAFT' and (private.current_user_role() in ('OWNER','MANAGER') or created_by=auth.uid()));

drop policy if exists receipt_import_lines_read on public.receipt_import_lines;
create policy receipt_import_lines_read on public.receipt_import_lines
for select to authenticated
using (exists (
  select 1 from public.receipt_imports r
  where r.id=receipt_import_id
    and (private.current_user_role() in ('OWNER','MANAGER') or r.created_by=auth.uid())
));

drop policy if exists receipt_import_lines_insert on public.receipt_import_lines;
create policy receipt_import_lines_insert on public.receipt_import_lines
for insert to authenticated
with check (exists (
  select 1 from public.receipt_imports r
  where r.id=receipt_import_id and r.status='DRAFT'
    and (private.current_user_role() in ('OWNER','MANAGER') or r.created_by=auth.uid())
));

drop policy if exists receipt_import_lines_update on public.receipt_import_lines;
create policy receipt_import_lines_update on public.receipt_import_lines
for update to authenticated
using (exists (
  select 1 from public.receipt_imports r
  where r.id=receipt_import_id and r.status='DRAFT'
    and (private.current_user_role() in ('OWNER','MANAGER') or r.created_by=auth.uid())
))
with check (exists (
  select 1 from public.receipt_imports r
  where r.id=receipt_import_id and r.status='DRAFT'
    and (private.current_user_role() in ('OWNER','MANAGER') or r.created_by=auth.uid())
));

drop policy if exists receipt_import_lines_delete on public.receipt_import_lines;
create policy receipt_import_lines_delete on public.receipt_import_lines
for delete to authenticated
using (exists (
  select 1 from public.receipt_imports r
  where r.id=receipt_import_id and r.status='DRAFT'
    and (private.current_user_role() in ('OWNER','MANAGER') or r.created_by=auth.uid())
));

create or replace function public.confirm_receipt_import(p_receipt_import_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_role public.user_role;
  v_receipt public.receipt_imports%rowtype;
  v_purchase_id uuid;
  v_purchase_no text;
  v_inventory_total numeric := 0;
  v_expense_total numeric := 0;
  v_line record;
  v_category_inventory boolean;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  v_role := private.current_user_role();
  if v_role not in ('OWNER','MANAGER') then raise exception 'MANAGEMENT_REQUIRED'; end if;

  select * into v_receipt
  from public.receipt_imports
  where id=p_receipt_import_id
  for update;

  if not found then raise exception 'RECEIPT_IMPORT_NOT_FOUND'; end if;
  if v_receipt.status <> 'DRAFT' then raise exception 'RECEIPT_IMPORT_NOT_DRAFT'; end if;
  if not exists(select 1 from public.receipt_import_lines where receipt_import_id=p_receipt_import_id) then
    raise exception 'RECEIPT_IMPORT_HAS_NO_LINES';
  end if;
  if exists(select 1 from public.receipt_import_lines where receipt_import_id=p_receipt_import_id and line_type='REVIEW') then
    raise exception 'RECEIPT_IMPORT_HAS_REVIEW_LINES';
  end if;

  select coalesce(sum(amount),0) into v_inventory_total
  from public.receipt_import_lines where receipt_import_id=p_receipt_import_id and line_type='INVENTORY';

  select coalesce(sum(amount),0) into v_expense_total
  from public.receipt_import_lines where receipt_import_id=p_receipt_import_id and line_type='EXPENSE';

  if v_inventory_total > 0 then
    if exists(
      select 1 from public.receipt_import_lines
      where receipt_import_id=p_receipt_import_id and line_type='INVENTORY'
        and (ingredient_id is null or purchase_unit_id is null)
    ) then raise exception 'INVENTORY_LINE_MISSING_MAPPING'; end if;

    v_purchase_no := 'RCPT-' || to_char(v_receipt.receipt_date,'YYYYMMDD') || '-' ||
                     upper(substr(replace(p_receipt_import_id::text,'-',''),1,8));

    insert into public.purchases(
      purchase_no,supplier_id,purchase_date,invoice_reference,subtotal,discount_amount,
      tax_amount,total_amount,payment_status,notes,status,created_by
    ) values (
      v_purchase_no,v_receipt.supplier_id,v_receipt.receipt_date,v_receipt.reference_no,
      v_inventory_total,0,0,v_inventory_total,'PAID',
      'สร้างจากการนำเข้าใบเสร็จรวม '||p_receipt_import_id::text||
      case when v_receipt.notes is null then '' else E'\n'||v_receipt.notes end,
      'DRAFT',v_uid
    ) returning id into v_purchase_id;

    insert into public.purchase_items(
      purchase_id,ingredient_id,purchase_quantity,purchase_unit_id,base_quantity,
      unit_price,line_total,cost_per_base_unit
    )
    select v_purchase_id,ingredient_id,quantity,purchase_unit_id,base_quantity,
           amount/quantity,amount,
           case when base_quantity is not null and base_quantity>0 then amount/base_quantity else null end
    from public.receipt_import_lines
    where receipt_import_id=p_receipt_import_id and line_type='INVENTORY';
  end if;

  for v_line in
    select l.* from public.receipt_import_lines l
    where l.receipt_import_id=p_receipt_import_id and l.line_type='EXPENSE'
    order by l.display_order,l.created_at
  loop
    if v_line.expense_category_id is null then raise exception 'EXPENSE_LINE_MISSING_CATEGORY'; end if;
    select is_inventory_related into v_category_inventory
    from public.expense_categories where id=v_line.expense_category_id;
    if coalesce(v_category_inventory,false) then raise exception 'INVENTORY_CATEGORY_NOT_ALLOWED_AS_EXPENSE'; end if;

    insert into public.expenses(
      expense_date,category_id,supplier_id,description,amount,payment_method,reference_no,
      receipt_url,related_purchase_id,notes,status,created_by
    ) values (
      v_receipt.receipt_date,v_line.expense_category_id,v_receipt.supplier_id,v_line.item_name,
      v_line.amount,v_receipt.payment_method,v_receipt.reference_no,v_receipt.receipt_url,
      v_purchase_id,
      coalesce(v_line.notes,'') || case when v_line.notes is null or v_line.notes='' then '' else E'\n' end ||
      'สร้างจากการนำเข้าใบเสร็จรวม '||p_receipt_import_id::text,
      'ACTIVE',v_uid
    );
  end loop;

  update public.receipt_imports
  set status='CONFIRMED',confirmed_by=v_uid,confirmed_at=now(),updated_at=now()
  where id=p_receipt_import_id;

  return jsonb_build_object(
    'receipt_import_id',p_receipt_import_id,'purchase_id',v_purchase_id,'purchase_no',v_purchase_no,
    'inventory_total',v_inventory_total,'expense_total',v_expense_total,
    'grand_total',v_inventory_total+v_expense_total
  );
end;
$$;

revoke all on function public.confirm_receipt_import(uuid) from public, anon;
grant execute on function public.confirm_receipt_import(uuid) to authenticated;
