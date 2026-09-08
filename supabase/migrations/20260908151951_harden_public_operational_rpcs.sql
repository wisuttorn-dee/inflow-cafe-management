-- Harden operational RPCs by removing SECURITY DEFINER from the exposed public API.
-- The privileged implementations are moved to the non-exposed private schema.

alter function public.commit_gpos_import(text,jsonb) set schema private;
alter function private.commit_gpos_import(text,jsonb) rename to commit_gpos_import_impl;

alter function public.process_pending_sales_inventory(uuid[]) set schema private;
alter function private.process_pending_sales_inventory(uuid[]) rename to process_pending_sales_inventory_impl;

alter function public.receive_purchase(uuid) set schema private;
alter function private.receive_purchase(uuid) rename to receive_purchase_impl;

alter function public.record_opening_stock(uuid,numeric,numeric,text) set schema private;
alter function private.record_opening_stock(uuid,numeric,numeric,text) rename to record_opening_stock_impl;

revoke all on function private.commit_gpos_import_impl(text,jsonb) from public,anon;
revoke all on function private.process_pending_sales_inventory_impl(uuid[]) from public,anon;
revoke all on function private.receive_purchase_impl(uuid) from public,anon;
revoke all on function private.record_opening_stock_impl(uuid,numeric,numeric,text) from public,anon;

grant execute on function private.commit_gpos_import_impl(text,jsonb) to authenticated;
grant execute on function private.process_pending_sales_inventory_impl(uuid[]) to authenticated;
grant execute on function private.receive_purchase_impl(uuid) to authenticated;
grant execute on function private.record_opening_stock_impl(uuid,numeric,numeric,text) to authenticated;

create or replace function public.commit_gpos_import(p_filename text,p_rows jsonb)
returns jsonb
language sql
security invoker
set search_path=''
as $$ select private.commit_gpos_import_impl(p_filename,p_rows) $$;

create or replace function public.process_pending_sales_inventory(p_sales_item_ids uuid[] default null)
returns jsonb
language sql
security invoker
set search_path=''
as $$ select private.process_pending_sales_inventory_impl(p_sales_item_ids) $$;

create or replace function public.receive_purchase(p_purchase_id uuid)
returns jsonb
language sql
security invoker
set search_path=''
as $$ select private.receive_purchase_impl(p_purchase_id) $$;

create or replace function public.record_opening_stock(p_ingredient_id uuid,p_quantity_base numeric,p_total_cost numeric,p_notes text default null)
returns uuid
language sql
security invoker
set search_path=''
as $$ select private.record_opening_stock_impl(p_ingredient_id,p_quantity_base,p_total_cost,p_notes) $$;

revoke all on function public.commit_gpos_import(text,jsonb) from public,anon;
revoke all on function public.process_pending_sales_inventory(uuid[]) from public,anon;
revoke all on function public.receive_purchase(uuid) from public,anon;
revoke all on function public.record_opening_stock(uuid,numeric,numeric,text) from public,anon;

grant execute on function public.commit_gpos_import(text,jsonb) to authenticated;
grant execute on function public.process_pending_sales_inventory(uuid[]) to authenticated;
grant execute on function public.receive_purchase(uuid) to authenticated;
grant execute on function public.record_opening_stock(uuid,numeric,numeric,text) to authenticated;
