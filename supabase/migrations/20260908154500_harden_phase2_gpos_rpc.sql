create or replace function public.check_gpos_duplicate_hashes(p_hashes text[])
returns table(source_row_hash text)
language sql
security invoker
set search_path = public
as $$
  select si.source_row_hash
  from public.sales_items si
  where si.source_row_hash = any(p_hashes)
$$;
revoke all on function public.check_gpos_duplicate_hashes(text[]) from public, anon;
grant execute on function public.check_gpos_duplicate_hashes(text[]) to authenticated;

create or replace function public.commit_gpos_import(p_filename text, p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_import_id uuid;
  v_role public.user_role;
  v_imported integer := 0;
  v_duplicates integer := 0;
  v_rejected integer := 0;
  v_unmapped integer := 0;
  v_gross numeric(14,2) := 0;
  v_discount numeric(14,2) := 0;
  v_net numeric(14,2) := 0;
  v_total_rows integer := jsonb_array_length(coalesce(p_rows, '[]'::jsonb));
  v_tx_id uuid;
  v_menu_item_id uuid;
  v_recipe_id uuid;
  v_sales_channel text;
  v_payment_method text;
  v_sold_at timestamptz;
  v_status public.import_status;
  r record;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select role into v_role from public.profiles where id = v_user and is_active = true;
  if v_role is null then raise exception 'Active user profile required'; end if;
  if nullif(trim(p_filename), '') is null then raise exception 'Filename is required'; end if;
  if v_total_rows = 0 then raise exception 'No GPOS rows supplied'; end if;

  insert into public.gpos_imports(original_filename, imported_by, total_source_rows, status)
  values (p_filename, v_user, v_total_rows, 'PROCESSING') returning id into v_import_id;

  for r in
    select * from jsonb_to_recordset(p_rows) as x(
      date_time text, invoice_no text, category text, item_name text,
      qty numeric, unit_price numeric, discount numeric, total numeric,
      payment text, source_row_hash text, normalised_item_name text
    )
  loop
    if nullif(trim(r.invoice_no), '') is null
       or nullif(trim(r.item_name), '') is null
       or nullif(trim(r.date_time), '') is null
       or r.qty is null or r.qty <= 0
       or r.unit_price is null or r.unit_price < 0
       or coalesce(r.discount,0) < 0
       or r.total is null or r.total < 0
       or nullif(trim(r.source_row_hash), '') is null
       or length(r.source_row_hash) <> 64
       or abs((r.qty * r.unit_price - coalesce(r.discount,0)) - r.total) > 0.05 then
      v_rejected := v_rejected + 1;
      continue;
    end if;

    if exists(select 1 from public.sales_items where source_row_hash = r.source_row_hash) then
      v_duplicates := v_duplicates + 1;
      continue;
    end if;

    begin
      v_sold_at := (r.date_time::timestamp at time zone 'Asia/Bangkok');
    exception when others then
      v_rejected := v_rejected + 1;
      continue;
    end;

    select m.menu_item_id into v_menu_item_id
    from public.gpos_product_mapping m
    where m.source_system = 'GPOS' and m.is_active = true
      and m.normalised_item_name = coalesce(nullif(trim(r.normalised_item_name), ''), lower(trim(r.item_name)))
    order by m.updated_at desc limit 1;

    v_recipe_id := null;
    if v_menu_item_id is not null then
      select rc.id into v_recipe_id
      from public.recipes rc
      where rc.menu_item_id = v_menu_item_id and rc.status = 'ACTIVE'
        and rc.effective_from <= (v_sold_at at time zone 'Asia/Bangkok')::date
        and (rc.effective_to is null or rc.effective_to >= (v_sold_at at time zone 'Asia/Bangkok')::date)
      order by rc.version_no desc limit 1;
    else
      v_unmapped := v_unmapped + 1;
    end if;

    select pcm.sales_channel, pcm.payment_method into v_sales_channel, v_payment_method
    from public.payment_channel_mapping pcm
    where pcm.is_active = true and pcm.gpos_value = coalesce(r.payment,'')
    order by pcm.updated_at desc limit 1;

    begin
      select id into v_tx_id from public.sales_transactions
      where source_system = 'GPOS' and invoice_no = r.invoice_no limit 1;

      if v_tx_id is null then
        insert into public.sales_transactions(
          source_system, invoice_no, sold_at, sales_date, sales_channel, payment_method,
          gross_amount, discount_amount, net_amount, import_id, status
        ) values (
          'GPOS', r.invoice_no, v_sold_at, (v_sold_at at time zone 'Asia/Bangkok')::date,
          v_sales_channel, v_payment_method, round((r.qty*r.unit_price)::numeric,2),
          round(coalesce(r.discount,0)::numeric,2), round(r.total::numeric,2), v_import_id, 'COMPLETED'
        ) returning id into v_tx_id;
      else
        update public.sales_transactions
        set gross_amount = gross_amount + round((r.qty*r.unit_price)::numeric,2),
            discount_amount = discount_amount + round(coalesce(r.discount,0)::numeric,2),
            net_amount = net_amount + round(r.total::numeric,2),
            sales_channel = coalesce(sales_channel, v_sales_channel),
            payment_method = coalesce(payment_method, v_payment_method)
        where id = v_tx_id;
      end if;

      insert into public.sales_items(
        sales_transaction_id, import_id, gpos_item_name, gpos_category,
        menu_item_id, recipe_id, quantity, unit_price, discount_amount,
        net_amount, source_row_hash, mapping_status
      ) values (
        v_tx_id, v_import_id, r.item_name, nullif(r.category,''),
        v_menu_item_id, v_recipe_id, r.qty, r.unit_price, coalesce(r.discount,0),
        r.total, r.source_row_hash,
        case when v_menu_item_id is null then 'UNMAPPED'::public.mapping_status else 'MATCHED'::public.mapping_status end
      );
    exception when unique_violation then
      v_duplicates := v_duplicates + 1;
      continue;
    end;

    v_imported := v_imported + 1;
    v_gross := v_gross + round((r.qty*r.unit_price)::numeric,2);
    v_discount := v_discount + round(coalesce(r.discount,0)::numeric,2);
    v_net := v_net + round(r.total::numeric,2);
  end loop;

  v_status := case when v_rejected > 0 then 'PARTIAL'::public.import_status else 'COMPLETED'::public.import_status end;
  update public.gpos_imports set completed_at=now(), imported_rows=v_imported,
    duplicate_rows=v_duplicates, rejected_rows=v_rejected, unmapped_rows=v_unmapped,
    gross_sales=v_gross, total_discount=v_discount, net_sales=v_net, status=v_status
  where id=v_import_id;

  insert into public.audit_logs(user_id,action,entity_type,entity_id,after_data)
  values(v_user,'IMPORT_COMPLETED','gpos_imports',v_import_id,
    jsonb_build_object('imported_rows',v_imported,'duplicate_rows',v_duplicates,'rejected_rows',v_rejected,'unmapped_rows',v_unmapped,'net_sales',v_net));

  return jsonb_build_object('import_id',v_import_id,'status',v_status,'total_source_rows',v_total_rows,
    'imported_rows',v_imported,'duplicate_rows',v_duplicates,'rejected_rows',v_rejected,
    'unmapped_rows',v_unmapped,'gross_sales',v_gross,'total_discount',v_discount,'net_sales',v_net);
end;
$$;
revoke all on function public.commit_gpos_import(text,jsonb) from public, anon;
grant execute on function public.commit_gpos_import(text,jsonb) to authenticated;
