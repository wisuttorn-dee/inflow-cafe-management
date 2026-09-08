create index if not exists stock_count_items_ingredient_idx on public.stock_count_items(ingredient_id);
create index if not exists stock_count_items_unit_idx on public.stock_count_items(unit_id);
create index if not exists stock_counts_started_by_idx on public.stock_counts(started_by);
create index if not exists stock_counts_completed_by_idx on public.stock_counts(completed_by) where completed_by is not null;
create index if not exists waste_records_unit_idx on public.waste_records(unit_id);
create index if not exists waste_records_recorded_by_idx on public.waste_records(recorded_by);
create index if not exists expenses_supplier_idx on public.expenses(supplier_id) where supplier_id is not null;
create index if not exists expenses_related_purchase_idx on public.expenses(related_purchase_id) where related_purchase_id is not null;
