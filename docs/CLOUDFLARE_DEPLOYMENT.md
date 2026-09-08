# Cloudflare Pages Deployment

## Project source
- GitHub repository: `wisuttorn-dee/inflow-cafe-management`
- Production branch: `main`

## Build settings
- Framework preset: Vite
- Build command: `npm run build`
- Build output directory: `dist`
- Node.js: use a current supported LTS release compatible with Vite 7

## Environment variables
Configure these in Cloudflare Pages for Production and Preview environments:

```text
VITE_SUPABASE_URL=https://zqcaparsxipudifybpho.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<Supabase publishable key from Project Settings / API Keys>
```

Never add a Supabase secret key or service-role key to Cloudflare Pages frontend variables.

## SPA routing
`public/_redirects` contains:

```text
/* /index.html 200
```

This ensures direct navigation and browser refreshes work for React Router routes.

## Security headers
`public/_headers` contains baseline browser security headers. Review them whenever new browser capabilities are added.

## Supabase Auth after first deployment
After Cloudflare provides the production Pages URL:

1. Open Supabase project `INFLOW Cafe Management`.
2. Go to Authentication URL configuration.
3. Set Site URL to the production Cloudflare Pages URL (or the final custom domain).
4. Add the production URL to Redirect URLs as required by the authentication flow.
5. Keep localhost redirect URLs only for development where needed.
6. Test login with the OWNER account and verify the profile role remains `OWNER`.

## Production smoke test
Verify:
- login/logout
- dashboard loads after refresh on nested routes
- GPOS Excel preview
- product/payment mapping
- import confirmation
- inventory processing
- purchase draft/receive
- waste
- stock count
- expense receipt upload/view
- monthly management report

Do not use the production database for disposable smoke-test transactions unless they are immediately reversed using supported application workflows.
