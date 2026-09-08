insert into storage.buckets (id,name,public)
values ('expense-receipts','expense-receipts',false)
on conflict (id) do update set public=false;

drop policy if exists expense_receipts_insert_own on storage.objects;
create policy expense_receipts_insert_own on storage.objects
for insert to authenticated
with check (
  bucket_id='expense-receipts'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
  and lower(storage.extension(name)) in ('pdf','jpg','jpeg','png','webp')
);

drop policy if exists expense_receipts_select on storage.objects;
create policy expense_receipts_select on storage.objects
for select to authenticated
using (
  bucket_id='expense-receipts'
  and (
    owner_id=(select auth.uid()::text)
    or (select private.current_user_role()) in ('OWNER','MANAGER')
  )
);

drop policy if exists expense_receipts_delete on storage.objects;
create policy expense_receipts_delete on storage.objects
for delete to authenticated
using (
  bucket_id='expense-receipts'
  and (
    owner_id=(select auth.uid()::text)
    or (select private.current_user_role()) in ('OWNER','MANAGER')
  )
);

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
