# INFLOW Café Management System

Phase 1 foundation for INFLOW Riverside Café. GPOS remains the sales source of truth. This application provides management, recipe, inventory, costing and reporting foundations.

## Stack

- React 19 + TypeScript + Vite
- Supabase PostgreSQL + Auth + Row Level Security
- Tailwind CSS
- SheetJS for GPOS `.xlsx` parsing
- Cloudflare Pages compatible SPA build

## Local setup

1. Copy `.env.example` to `.env.local`.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`. Never place a secret/service role key in frontend variables.
3. Run `npm install`.
4. Run `npm run dev`.

## Supabase

Linked project ref: `zqcaparsxipudifybpho` (`INFLOW Cafe Management`).

Migrations live in `supabase/migrations`. Apply them in order with the Supabase CLI or project workflow. New public tables use explicit authenticated grants and RLS because new Supabase projects no longer auto-expose tables to the Data API by default.

Generate database types with:

```bash
supabase gen types typescript --project-id zqcaparsxipudifybpho --schema public > src/types/database.ts
```

## Phase 1 features

- Supabase Auth sign-in
- OWNER / MANAGER / STAFF role model
- RLS-protected master data and operational foundation
- Master-data interfaces for units, menu categories, menu items, ingredients and suppliers
- Responsive application shell and navigation
- GPOS Excel preview using the actual report columns
- Required-column validation and arithmetic validation
- Source-row SHA-256 hashing utility for Phase 2 duplicate prevention
- Inventory movement ledger model, with no editable authoritative current-stock field
- Placeholder screens for later modules

## GPOS required source concepts

Required: Date-Time, Invoice No., Item Name, Qty, Unit Price, Total. Optional: Category, Discount, Payment. Thai/English headers from the supplied GPOS workbook are recognised. Phase 1 does not commit sales to the database.

## Quality checks

```bash
npm run lint
npm run typecheck
npm run build
```

GitHub Actions runs the same checks. The first CI run also creates and commits `package-lock.json` if it is missing so dependencies become reproducible.

## Deployment preparation

The Vite `dist/` output is compatible with Cloudflare Pages. Do not deploy until Phase 1 validation is accepted. Configure the same two public Supabase environment variables in the hosting environment.

## Phase 2

Next work: duplicate lookup against `source_row_hash`, product mapping workflow, payment/channel mapping, transactional GPOS commit, atomic sales creation, recipe-version resolution, inventory consumption, historical cost snapshots and import history/reversal controls.
