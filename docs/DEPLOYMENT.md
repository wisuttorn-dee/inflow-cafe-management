# Production Deployment Runbook

## Target

- Frontend: Cloudflare Pages
- Project name: `inflow-cafe-management`
- Production branch: `main`
- Build command: `npm run build`
- Output directory: `dist`
- SPA fallback: `public/_redirects` contains `/* /index.html 200`
- Backend: Supabase project `INFLOW Cafe Management` (`zqcaparsxipudifybpho`)

## Required GitHub Environment secrets

Create a GitHub Environment named `production` and add:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Never store a Supabase secret/service-role key in the frontend or repository.

The Cloudflare API token should be scoped only to the account/project permissions required for Pages deployment.

## Deploy

The workflow `.github/workflows/deploy-cloudflare-pages.yml` is manual-only. It deliberately does not deploy on every push.

1. Confirm the normal CI workflow on `main` is green.
2. Open GitHub → Actions → **Deploy Cloudflare Pages**.
3. Select **Run workflow** on `main`.
4. The workflow validates all required secrets, runs lint/typecheck/build, creates the Pages project if needed, and deploys `dist`.
5. Record the resulting `*.pages.dev` production URL.

Wrangler is pinned in the workflow for reproducible deployment.

## Supabase Auth after the first deployment

After the final production URL is known:

1. Open Supabase → Authentication → URL Configuration.
2. Set **Site URL** to the production HTTPS origin.
3. Add the same production origin to allowed Redirect URLs when required by the authentication flow.
4. Keep local development URLs only if local sign-in testing is still required.
5. Do not use wildcard production redirects unless there is a specific documented need.

## Production smoke test

Use the existing OWNER account. Do not put passwords in CI logs, screenshots, issues, or repository files.

Verify:

1. Login succeeds over HTTPS.
2. OWNER profile is loaded and role is `OWNER`.
3. Dashboard navigation works after refreshing nested routes.
4. Units/ingredients/menu CRUD loads through RLS.
5. GPOS Excel preview parses locally in the browser.
6. Receipt upload remains private and viewing uses a signed URL.
7. Low Stock and Reports load successfully.
8. No browser console shows service-role or secret credentials.

## Security checks

Before declaring production ready:

- Supabase Security Advisor: no database/RLS/RPC findings.
- Review Auth security settings and use a strong unique OWNER password.
- Enable leaked-password protection if the Supabase plan supports it.
- Confirm the repository contains no `.env` or secret values.
- Review Cloudflare token scope and rotate it if it was ever exposed.

## Rollback

Cloudflare Pages retains deployment history. If a deployment is bad, promote/redeploy the last known-good commit rather than changing database data to compensate for a frontend regression.

Database schema changes remain migration-controlled in `supabase/migrations`; do not manually delete production migrations to roll back application code.
