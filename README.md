# INFLOW Café Management System

Internal management application for INFLOW Riverside Café. GPOS remains the point-of-sale source of truth. INFLOW adds recipe costing, inventory, purchasing, waste, stock count, expenses, management reporting and operational controls.

## Stack

- React 19 + TypeScript + Vite
- Supabase PostgreSQL + Auth + Row Level Security
- Supabase Storage for private expense receipts
- Supabase Edge Function for OWNER-only user administration
- Tailwind CSS
- `read-excel-file` for browser-side GPOS `.xlsx` parsing
- Cloudflare Pages compatible SPA build

## Local setup

1. Copy `.env.example` to `.env.local`.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
3. Never place a Supabase secret/service-role key in frontend variables or GitHub.
4. Run `npm install`.
5. Run `npm run dev`.

## Supabase

Project ref: `zqcaparsxipudifybpho` (`INFLOW Cafe Management`).

Migrations live in `supabase/migrations`. Public operational tables use explicit authenticated grants plus Row Level Security. Inventory quantity is ledger-derived; there is no authoritative editable `current_stock` field.

Generate database types with:

```bash
supabase gen types typescript --project-id zqcaparsxipudifybpho --schema public > src/types/database.ts
```

## Security architecture

Operational RPCs exposed through the public Data API are `SECURITY INVOKER`. Where a workflow genuinely needs privileged atomic database access, the implementation is kept in the non-exposed `private` schema, checks `auth.uid()` and the active application role, and is invoked by a thin public wrapper.

Current production database check: no `SECURITY DEFINER` functions remain in the exposed `public` schema and the latest Supabase Security Advisor scan reports zero security lints.

`anon` has no execute permission on the protected operational RPCs.

## First OWNER bootstrap

The database is designed so that the **first Supabase Auth user created becomes OWNER automatically**. Every later Auth user starts as STAFF until an OWNER changes the role.

Safe first-use process:

1. Open Supabase Dashboard → Authentication → Users.
2. Create the first user with the café owner's real email and a strong password.
3. Do not create test/staff accounts before the OWNER account.
4. Sign in to INFLOW with that account.
5. Open Settings → User Management to create MANAGER/STAFF accounts.

The frontend intentionally does not provide public sign-up.

## Implemented operational flow

```text
GPOS Excel
→ validation / duplicate detection
→ product & payment mapping
→ committed sales
→ recipe version
→ ingredient usage
→ inventory ledger
→ historical COGS
→ gross profit

Purchasing → PURCHASE movements → weighted-average cost
Waste → WASTE movements
Stock Count → STOCK_COUNT_ADJUSTMENT
Expenses → monthly operating profit
```

## Private receipt storage

Expense receipts use private bucket `expense-receipts`.

- Supported: PDF, JPG/JPEG, PNG, WebP
- Frontend limit: 5 MB per file
- STAFF uploads only to their own user folder
- OWNER/MANAGER can read receipts for management review
- Receipt viewing uses short-lived signed URLs
- No public receipt URLs are stored

## Low Stock Purchase Suggestions

The Low Stock page can create a **DRAFT purchase** from selected shortages. The draft uses the shortage to the configured minimum level and the current weighted-average cost as an estimate.

Creating a suggestion never changes inventory. OWNER/MANAGER must review supplier, quantity and price and then explicitly Receive the purchase before stock changes.

## Quality checks

```bash
npm run lint
npm run typecheck
npm run build
```

GitHub Actions runs the same checks and keeps `package-lock.json` committed.

## Deployment

The Vite `dist/` output is compatible with Cloudflare Pages. Before production deployment:

1. Create the first real OWNER account.
2. Run the authenticated end-to-end workflow using controlled café test data.
3. Confirm GPOS import totals, recipe usage, inventory movement, COGS, expenses and monthly profit.
4. Confirm Supabase Security Advisor remains clean.
5. Review repository visibility and hosting environment variables.
6. Configure the Supabase Auth site URL / redirect URLs for the production domain.
