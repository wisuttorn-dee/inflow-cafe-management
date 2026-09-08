create extension if not exists pgcrypto;

create type public.user_role as enum ('OWNER','MANAGER','STAFF');
create type public.recipe_status as enum ('DRAFT','ACTIVE','INACTIVE');
create type public.import_status as enum ('PREVIEW','PROCESSING','COMPLETED','FAILED','PARTIAL','REVERSED');
create type public.mapping_status as enum ('MATCHED','UNMAPPED','IGNORED');
create type public.sales_status as enum ('COMPLETED','REVERSED','ADJUSTED');
create type public.movement_type as enum ('OPENING','PURCHASE','SALE_USAGE','WASTE','STOCK_ADJUSTMENT','STOCK_COUNT_ADJUSTMENT','RETURN_TO_SUPPLIER','REVERSAL','TRANSFER_IN','TRANSFER_OUT');

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, display_name text, role public.user_role not null default 'STAFF', is_active boolean not null default true,
 last_login_at timestamptz, updated_by uuid references auth.users, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.units (
 id uuid primary key default gen_random_uuid(), code text not null unique, name_th text not null, name_en text not null,
 unit_type text not null check (unit_type in ('WEIGHT','VOLUME','COUNT','PURCHASE_UNIT')), decimal_places integer not null default 2 check(decimal_places between 0 and 6), is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
create table public.suppliers (
 id uuid primary key default gen_random_uuid(), supplier_code text unique, supplier_name text not null, contact_name text, phone text, email text, address text, tax_id text, notes text,
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
create table public.unit_conversions (
 id uuid primary key default gen_random_uuid(), from_unit_id uuid not null references public.units, to_unit_id uuid not null references public.units,
 conversion_factor numeric(18,6) not null check(conversion_factor>0), ingredient_id uuid, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users,
 unique(from_unit_id,to_unit_id,ingredient_id)
);
create table public.menu_categories (
 id uuid primary key default gen_random_uuid(), name_th text not null, name_en text, display_order integer not null default 0, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
create table public.ingredients (
 id uuid primary key default gen_random_uuid(), ingredient_code text not null unique, name_th text not null, name_en text, base_unit_id uuid not null references public.units,
 ingredient_category text, minimum_stock_level numeric(14,4) not null default 0 check(minimum_stock_level>=0), preferred_supplier_id uuid references public.suppliers,
 is_active boolean not null default true, track_stock boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
alter table public.unit_conversions add constraint unit_conversions_ingredient_id_fkey foreign key(ingredient_id) references public.ingredients(id);
create table public.menu_items (
 id uuid primary key default gen_random_uuid(), sku text unique, category_id uuid references public.menu_categories, name_th text not null, name_en text,
 selling_price numeric(14,2) not null default 0 check(selling_price>=0), is_active boolean not null default true, track_inventory boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
create table public.recipes (
 id uuid primary key default gen_random_uuid(), menu_item_id uuid not null references public.menu_items, recipe_name text not null, version_no integer not null default 1 check(version_no>0),
 yield_quantity numeric(14,4) not null default 1 check(yield_quantity>0), yield_unit_id uuid references public.units, effective_from date not null default current_date, effective_to date,
 status public.recipe_status not null default 'DRAFT', notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users,
 unique(menu_item_id,version_no), check(effective_to is null or effective_to>=effective_from)
);
alter table public.menu_items add column default_recipe_id uuid references public.recipes(id);
create table public.recipe_items (
 id uuid primary key default gen_random_uuid(), recipe_id uuid not null references public.recipes on delete cascade, ingredient_id uuid not null references public.ingredients,
 quantity numeric(14,4) not null check(quantity>0), unit_id uuid not null references public.units, wastage_percentage numeric(7,4) not null default 0 check(wastage_percentage>=0), display_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users,
 unique(recipe_id,ingredient_id)
);
create table public.gpos_imports (
 id uuid primary key default gen_random_uuid(), original_filename text not null, file_checksum text, source_system text not null default 'GPOS', started_at timestamptz not null default now(), completed_at timestamptz,
 imported_by uuid not null references auth.users, total_source_rows integer not null default 0 check(total_source_rows>=0), imported_rows integer not null default 0 check(imported_rows>=0), duplicate_rows integer not null default 0 check(duplicate_rows>=0), rejected_rows integer not null default 0 check(rejected_rows>=0), unmapped_rows integer not null default 0 check(unmapped_rows>=0), gross_sales numeric(14,2) not null default 0, total_discount numeric(14,2) not null default 0, net_sales numeric(14,2) not null default 0,
 status public.import_status not null default 'PREVIEW', reversed_at timestamptz, reversed_by uuid references auth.users, reversal_reason text, created_at timestamptz not null default now()
);
create table public.gpos_product_mapping (
 id uuid primary key default gen_random_uuid(), source_system text not null default 'GPOS', external_product_id text, external_item_name text not null, normalised_item_name text not null,
 menu_item_id uuid not null references public.menu_items, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users,
 unique(source_system,normalised_item_name)
);
create table public.payment_channel_mapping (
 id uuid primary key default gen_random_uuid(), gpos_value text not null unique, sales_channel text not null, payment_method text not null, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid references auth.users, updated_by uuid references auth.users
);
create table public.sales_transactions (
 id uuid primary key default gen_random_uuid(), source_system text not null default 'GPOS', invoice_no text not null, sold_at timestamptz not null, sales_date date not null,
 sales_channel text, payment_method text, gross_amount numeric(14,2) not null default 0, discount_amount numeric(14,2) not null default 0, net_amount numeric(14,2) not null default 0,
 import_id uuid not null references public.gpos_imports, status public.sales_status not null default 'COMPLETED', created_at timestamptz not null default now(), unique(source_system,invoice_no)
);
create table public.sales_items (
 id uuid primary key default gen_random_uuid(), sales_transaction_id uuid not null references public.sales_transactions, import_id uuid not null references public.gpos_imports,
 gpos_item_name text not null, gpos_category text, menu_item_id uuid references public.menu_items, recipe_id uuid references public.recipes, quantity numeric(14,4) not null check(quantity>0),
 unit_price numeric(14,2) not null check(unit_price>=0), discount_amount numeric(14,2) not null default 0 check(discount_amount>=0), net_amount numeric(14,2) not null check(net_amount>=0),
 source_row_hash text not null unique, unit_cost_snapshot numeric(14,4), total_cost_snapshot numeric(14,2), mapping_status public.mapping_status not null default 'UNMAPPED', created_at timestamptz not null default now()
);
create table public.inventory_movements (
 id uuid primary key default gen_random_uuid(), ingredient_id uuid not null references public.ingredients, movement_type public.movement_type not null, quantity_base_unit numeric(14,4) not null,
 unit_cost numeric(14,4), total_cost numeric(14,2), reference_type text, reference_id uuid, sales_item_id uuid references public.sales_items, purchase_item_id uuid, stock_count_id uuid,
 occurred_at timestamptz not null default now(), notes text, created_by uuid references auth.users, created_at timestamptz not null default now()
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), user_id uuid references auth.users, action text not null, entity_type text not null, entity_id uuid,
 before_data jsonb, after_data jsonb, metadata jsonb, occurred_at timestamptz not null default now()
);

create schema if not exists private;
create or replace function private.current_user_role() returns public.user_role language sql stable security definer set search_path=public,pg_temp as $$
 select p.role from public.profiles p where p.id=auth.uid() and p.is_active=true limit 1
$$;
revoke all on function private.current_user_role() from public, anon;
grant execute on function private.current_user_role() to authenticated;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); new.updated_by=coalesce(auth.uid(),new.updated_by); return new; end $$;
revoke all on function public.set_updated_at() from public, anon, authenticated;

create or replace function private.handle_new_user() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$ begin insert into public.profiles(id,full_name,display_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1)),'STAFF') on conflict(id) do nothing; return new; end $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

create trigger units_updated before update on public.units for each row execute function public.set_updated_at();
create trigger suppliers_updated before update on public.suppliers for each row execute function public.set_updated_at();
create trigger unit_conversions_updated before update on public.unit_conversions for each row execute function public.set_updated_at();
create trigger menu_categories_updated before update on public.menu_categories for each row execute function public.set_updated_at();
create trigger ingredients_updated before update on public.ingredients for each row execute function public.set_updated_at();
create trigger menu_items_updated before update on public.menu_items for each row execute function public.set_updated_at();
create trigger recipes_updated before update on public.recipes for each row execute function public.set_updated_at();
create trigger recipe_items_updated before update on public.recipe_items for each row execute function public.set_updated_at();
create trigger gpos_product_mapping_updated before update on public.gpos_product_mapping for each row execute function public.set_updated_at();
create trigger payment_channel_mapping_updated before update on public.payment_channel_mapping for each row execute function public.set_updated_at();
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;alter table public.units enable row level security;alter table public.unit_conversions enable row level security;alter table public.menu_categories enable row level security;alter table public.menu_items enable row level security;alter table public.ingredients enable row level security;alter table public.suppliers enable row level security;alter table public.recipes enable row level security;alter table public.recipe_items enable row level security;alter table public.gpos_imports enable row level security;alter table public.gpos_product_mapping enable row level security;alter table public.payment_channel_mapping enable row level security;alter table public.sales_transactions enable row level security;alter table public.sales_items enable row level security;alter table public.inventory_movements enable row level security;alter table public.audit_logs enable row level security;

grant usage on schema public to authenticated;grant usage on schema private to authenticated;
grant select on public.profiles to authenticated;
grant select,insert,update on public.units,public.unit_conversions,public.menu_categories,public.menu_items,public.ingredients,public.suppliers,public.recipes,public.recipe_items,public.gpos_product_mapping,public.payment_channel_mapping to authenticated;
grant select,insert on public.gpos_imports,public.sales_transactions,public.sales_items,public.inventory_movements to authenticated;
grant select on public.audit_logs to authenticated;

create policy profiles_read_self_or_management on public.profiles for select to authenticated using(id=auth.uid() or private.current_user_role() in ('OWNER','MANAGER'));
create policy profiles_owner_update on public.profiles for update to authenticated using(private.current_user_role()='OWNER') with check(private.current_user_role()='OWNER');

create policy units_read on public.units for select to authenticated using(true);create policy units_manage on public.units for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy unit_conversions_read on public.unit_conversions for select to authenticated using(true);create policy unit_conversions_manage on public.unit_conversions for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy categories_read on public.menu_categories for select to authenticated using(true);create policy categories_manage on public.menu_categories for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy menu_items_read on public.menu_items for select to authenticated using(true);create policy menu_items_manage on public.menu_items for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy ingredients_read on public.ingredients for select to authenticated using(true);create policy ingredients_manage on public.ingredients for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy suppliers_read on public.suppliers for select to authenticated using(true);create policy suppliers_manage on public.suppliers for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy recipes_read on public.recipes for select to authenticated using(true);create policy recipes_manage on public.recipes for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy recipe_items_read on public.recipe_items for select to authenticated using(true);create policy recipe_items_manage on public.recipe_items for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy mapping_read on public.gpos_product_mapping for select to authenticated using(true);create policy mapping_manage on public.gpos_product_mapping for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));
create policy payment_mapping_read on public.payment_channel_mapping for select to authenticated using(true);create policy payment_mapping_manage on public.payment_channel_mapping for all to authenticated using(private.current_user_role() in ('OWNER','MANAGER')) with check(private.current_user_role() in ('OWNER','MANAGER'));

create policy imports_read on public.gpos_imports for select to authenticated using(private.current_user_role() in ('OWNER','MANAGER','STAFF'));create policy imports_insert on public.gpos_imports for insert to authenticated with check(imported_by=auth.uid() and private.current_user_role() in ('OWNER','MANAGER','STAFF'));
create policy transactions_read on public.sales_transactions for select to authenticated using(private.current_user_role() in ('OWNER','MANAGER','STAFF'));create policy transactions_insert on public.sales_transactions for insert to authenticated with check(private.current_user_role() in ('OWNER','MANAGER','STAFF'));
create policy sales_items_read on public.sales_items for select to authenticated using(private.current_user_role() in ('OWNER','MANAGER','STAFF'));create policy sales_items_insert on public.sales_items for insert to authenticated with check(private.current_user_role() in ('OWNER','MANAGER','STAFF'));
create policy inventory_read on public.inventory_movements for select to authenticated using(private.current_user_role() in ('OWNER','MANAGER','STAFF'));create policy inventory_insert on public.inventory_movements for insert to authenticated with check(private.current_user_role() in ('OWNER','MANAGER','STAFF'));
create policy audit_management_read on public.audit_logs for select to authenticated using(private.current_user_role() in ('OWNER','MANAGER'));

create index idx_sales_transactions_sold_at on public.sales_transactions(sold_at);create index idx_sales_items_menu on public.sales_items(menu_item_id);create index idx_inventory_movements_ingredient_time on public.inventory_movements(ingredient_id,occurred_at);create index idx_gpos_imports_started on public.gpos_imports(started_at);
