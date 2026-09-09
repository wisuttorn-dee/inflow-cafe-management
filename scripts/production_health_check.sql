\set ON_ERROR_STOP on
\echo 'INFLOW production health check'

DO $$
DECLARE
  v_count integer;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND NOT c.relrowsecurity;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Security check failed: % public tables have RLS disabled', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prosecdef;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Security check failed: % public SECURITY DEFINER functions found', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM (
    SELECT source_row_hash
    FROM public.sales_items
    WHERE source_row_hash IS NOT NULL
    GROUP BY source_row_hash
    HAVING count(*) > 1
  ) d;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Data check failed: % duplicate GPOS source hashes found', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.sales_transactions
  WHERE abs(coalesce(gross_amount,0) - coalesce(discount_amount,0) - coalesce(net_amount,0)) > 0.05;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Data check failed: % sales transactions have amount mismatch', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.sales_items
  WHERE abs(coalesce(quantity,0) * coalesce(unit_price,0) - coalesce(discount_amount,0) - coalesce(net_amount,0)) > 0.05;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Data check failed: % sales items have amount mismatch', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.sales_items
  WHERE costing_status = 'PROCESSED'
    AND (unit_cost_snapshot IS NULL OR total_cost_snapshot IS NULL);
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Costing check failed: % processed sales items are missing cost snapshots', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.gpos_imports
  WHERE coalesce(imported_rows,0) + coalesce(duplicate_rows,0) + coalesce(rejected_rows,0) <> coalesce(total_source_rows,0)
    AND status IN ('COMPLETED','PARTIAL');
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Import check failed: % completed imports have row-count mismatch', v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.purchases p
  WHERE p.status = 'RECEIVED'
    AND abs(coalesce(p.total_amount,0) - (coalesce(p.subtotal,0) - coalesce(p.discount_amount,0) + coalesce(p.tax_amount,0))) > 0.05;
  IF v_count > 0 THEN
    RAISE EXCEPTION 'Purchase check failed: % received purchases have total mismatch', v_count;
  END IF;
END $$;

\echo 'Operational warning summary (non-failing)'
SELECT
  (SELECT count(*) FROM public.sales_items WHERE costing_status IN ('PENDING','MISSING_COST','ERROR')) AS incomplete_costing_rows,
  (SELECT count(*) FROM public.sales_items WHERE mapping_status = 'UNMAPPED') AS unmapped_sales_rows,
  (SELECT count(*) FROM public.inventory_summary WHERE current_quantity < 0) AS negative_stock_items,
  (SELECT count(*) FROM public.inventory_summary WHERE is_low_stock) AS low_stock_items,
  (SELECT count(*) FROM public.stock_counts WHERE status = 'DRAFT') AS open_stock_counts,
  (SELECT count(*) FROM public.purchases WHERE status = 'DRAFT') AS draft_purchases;

\echo 'INFLOW production health check passed'
