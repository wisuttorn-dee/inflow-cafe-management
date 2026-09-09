\set ON_ERROR_STOP on
\echo 'INFLOW back-office regression test (transaction rollback)'

BEGIN;

SELECT id::text AS owner_id
FROM public.profiles
WHERE role = 'OWNER' AND is_active = true
ORDER BY created_at
LIMIT 1
\gset

\if :{?owner_id}
\else
  \echo 'No active OWNER profile found'
  \quit 2
\endif

SELECT set_config(
  'request.jwt.claims',
  json_build_object('sub', :'owner_id', 'role', 'authenticated')::text,
  true
);
SET LOCAL ROLE authenticated;

SELECT
  gen_random_uuid()::text AS unit_id,
  gen_random_uuid()::text AS ingredient_id,
  gen_random_uuid()::text AS category_id,
  gen_random_uuid()::text AS menu_item_id,
  gen_random_uuid()::text AS recipe_id,
  gen_random_uuid()::text AS purchase_id,
  gen_random_uuid()::text AS purchase_item_id,
  gen_random_uuid()::text AS expense_category_id
\gset

SELECT set_config('inflow.e2e_ingredient_id', :'ingredient_id', true);

INSERT INTO public.units(id, code, name_th, name_en, unit_type, decimal_places)
VALUES (:'unit_id'::uuid, 'E2E_G', 'กรัมทดสอบ', 'E2E gram', 'WEIGHT', 2);

INSERT INTO public.ingredients(id, ingredient_code, name_th, name_en, base_unit_id, minimum_stock_level)
VALUES (:'ingredient_id'::uuid, 'E2E-ING', 'วัตถุดิบทดสอบ', 'E2E ingredient', :'unit_id'::uuid, 100);

INSERT INTO public.menu_categories(id, name_th, name_en, display_order)
VALUES (:'category_id'::uuid, 'หมวดทดสอบ', 'E2E category', 9999);

INSERT INTO public.menu_items(id, category_id, name_th, name_en, selling_price, track_inventory)
VALUES (:'menu_item_id'::uuid, :'category_id'::uuid, 'เมนูทดสอบ', 'E2E drink', 100, true);

INSERT INTO public.recipes(id, menu_item_id, recipe_name, version_no, yield_quantity, yield_unit_id, effective_from, status)
VALUES (:'recipe_id'::uuid, :'menu_item_id'::uuid, 'E2E recipe', 1, 1, :'unit_id'::uuid, current_date, 'ACTIVE');

INSERT INTO public.recipe_items(recipe_id, ingredient_id, quantity, unit_id, wastage_percentage, display_order)
VALUES (:'recipe_id'::uuid, :'ingredient_id'::uuid, 100, :'unit_id'::uuid, 0, 1);

UPDATE public.menu_items SET default_recipe_id = :'recipe_id'::uuid WHERE id = :'menu_item_id'::uuid;

INSERT INTO public.gpos_product_mapping(external_item_name, normalised_item_name, menu_item_id)
VALUES ('AUTO E2E DRINK', 'auto e2e drink', :'menu_item_id'::uuid);

INSERT INTO public.payment_channel_mapping(gpos_value, sales_channel, payment_method)
VALUES ('AUTO_E2E_PAY', 'WALK_IN', 'CASH');

SELECT public.record_opening_stock(:'ingredient_id'::uuid, 1000, 1000, 'Automated E2E opening stock');

SELECT public.commit_gpos_import(
  'auto-e2e.xlsx',
  jsonb_build_array(jsonb_build_object(
    'date_time', to_char(clock_timestamp() AT TIME ZONE 'Asia/Bangkok', 'YYYY-MM-DD HH24:MI:SS'),
    'invoice_no', 'AUTO-E2E-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS'),
    'category', 'E2E',
    'item_name', 'AUTO E2E DRINK',
    'qty', 2,
    'unit_price', 100,
    'discount', 0,
    'total', 200,
    'payment', 'AUTO_E2E_PAY',
    'source_row_hash', repeat('e',64),
    'normalised_item_name', 'auto e2e drink'
  ))
) AS import_result
\gset

SELECT id::text AS sales_item_id
FROM public.sales_items
WHERE source_row_hash = repeat('e',64)
LIMIT 1
\gset

SELECT public.process_pending_sales_inventory(ARRAY[:'sales_item_id'::uuid]);

DO $$
DECLARE
  v_qty numeric;
  v_cost numeric;
  v_ingredient uuid := current_setting('inflow.e2e_ingredient_id')::uuid;
BEGIN
  SELECT current_quantity, current_value INTO v_qty, v_cost
  FROM public.inventory_summary
  WHERE ingredient_id = v_ingredient;
  IF abs(v_qty - 800) > 0.001 THEN
    RAISE EXCEPTION 'Expected stock 800 after sales usage, got %', v_qty;
  END IF;
  IF abs(v_cost - 800) > 0.05 THEN
    RAISE EXCEPTION 'Expected stock value 800 after sales usage, got %', v_cost;
  END IF;
END $$;

INSERT INTO public.purchases(id, purchase_no, purchase_date, subtotal, discount_amount, tax_amount, total_amount, status)
VALUES (:'purchase_id'::uuid, 'AUTO-E2E-PURCHASE', current_date, 300, 0, 0, 300, 'DRAFT');

INSERT INTO public.purchase_items(id, purchase_id, ingredient_id, purchase_quantity, purchase_unit_id, unit_price, line_total)
VALUES (:'purchase_item_id'::uuid, :'purchase_id'::uuid, :'ingredient_id'::uuid, 200, :'unit_id'::uuid, 1.5, 300);

SELECT public.receive_purchase(:'purchase_id'::uuid);

DO $$
DECLARE
  v_qty numeric;
  v_avg numeric;
  v_ingredient uuid := current_setting('inflow.e2e_ingredient_id')::uuid;
BEGIN
  SELECT current_quantity, weighted_avg_cost INTO v_qty, v_avg
  FROM public.inventory_summary
  WHERE ingredient_id = v_ingredient;
  IF abs(v_qty - 1000) > 0.001 THEN
    RAISE EXCEPTION 'Expected stock 1000 after purchase, got %', v_qty;
  END IF;
  IF abs(v_avg - 1.1) > 0.0001 THEN
    RAISE EXCEPTION 'Expected weighted average 1.10, got %', v_avg;
  END IF;
END $$;

SELECT public.record_waste(:'ingredient_id'::uuid, 10, :'unit_id'::uuid, 'SPILLAGE', 'Automated E2E waste', now());

SELECT public.create_stock_count(current_date, 'Automated E2E stock count')::text AS stock_count_id
\gset

UPDATE public.stock_count_items
SET actual_quantity = 980
WHERE stock_count_id = :'stock_count_id'::uuid
  AND ingredient_id = :'ingredient_id'::uuid;

SELECT public.finalize_stock_count(:'stock_count_id'::uuid);

INSERT INTO public.expense_categories(id, code, name_th, name_en, is_inventory_related)
VALUES (:'expense_category_id'::uuid, 'AUTO-E2E', 'ค่าใช้จ่ายทดสอบ', 'E2E expense', false);

SELECT public.record_expense(
  current_date,
  :'expense_category_id'::uuid,
  'Automated E2E expense',
  50,
  'CASH',
  NULL,
  'AUTO-E2E',
  'Rollback test only'
);

DO $$
DECLARE
  v_qty numeric;
  v_summary jsonb;
  v_ingredient uuid := current_setting('inflow.e2e_ingredient_id')::uuid;
BEGIN
  SELECT current_quantity INTO v_qty
  FROM public.inventory_summary
  WHERE ingredient_id = v_ingredient;
  IF abs(v_qty - 980) > 0.001 THEN
    RAISE EXCEPTION 'Expected final stock 980, got %', v_qty;
  END IF;

  SELECT public.get_management_summary(date_trunc('month', current_date)::date) INTO v_summary;
  IF v_summary IS NULL THEN
    RAISE EXCEPTION 'Management summary returned NULL';
  END IF;
END $$;

ROLLBACK;

\echo 'Rollback completed — no E2E rows persisted'
\echo 'INFLOW back-office regression test passed'
