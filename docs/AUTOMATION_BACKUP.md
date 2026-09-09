# INFLOW Automated Testing & Backup Runbook

## 1. Production health check

Workflow: `.github/workflows/production-health-check.yml`

Runs daily at 09:00 Asia/Bangkok and can also be triggered manually.

It performs:

- RLS enabled check for public tables
- no `SECURITY DEFINER` functions in the public schema
- duplicate GPOS source-row hash detection
- sales transaction arithmetic validation
- sales item arithmetic validation
- processed COGS snapshot validation
- completed GPOS import row reconciliation
- received purchase total reconciliation
- warning summary for incomplete costing, unmapped sales, negative stock, low stock, open stock counts, and draft purchases
- a full back-office regression scenario inside one database transaction followed by `ROLLBACK`

The rollback regression exercises:

`Opening Stock -> GPOS Import -> Recipe Usage -> Inventory -> COGS -> Purchase Receive -> Weighted Average Cost -> Waste -> Stock Count -> Expense -> Management Summary`

No test rows are committed when the workflow passes.

Required GitHub `production` environment secret:

- `SUPABASE_DB_URL`

Use a Supabase PostgreSQL connection URI. Treat this value as highly sensitive.

## 2. Encrypted database backup

Workflow: `.github/workflows/encrypted-database-backup.yml`

Runs daily at 10:00 Asia/Bangkok and can also be triggered manually.

The workflow:

1. creates a PostgreSQL custom-format dump with `pg_dump`
2. encrypts the dump using AES-256-CBC with PBKDF2
3. creates a SHA-256 checksum
4. deletes the unencrypted dump
5. uploads only the encrypted file and checksum as a GitHub Actions artifact
6. retains the artifact for 7 days

Required GitHub `production` environment secrets:

- `SUPABASE_DB_URL`
- `BACKUP_PASSPHRASE` — at least 20 characters; store it outside GitHub as well

Never commit database dumps, database passwords, service-role keys, or backup passphrases to this public repository.

### Restore a database backup locally

Download the encrypted artifact and checksum from GitHub Actions, then:

```bash
sha256sum -c inflow-YYYYMMDDTHHMMSSZ.dump.enc.sha256
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in inflow-YYYYMMDDTHHMMSSZ.dump.enc \
  -out inflow-restored.dump \
  -pass env:BACKUP_PASSPHRASE

pg_restore --list inflow-restored.dump
```

Restore first into a disposable/test PostgreSQL database. Do not restore directly over production without reviewing the dump and taking a fresh backup.

## 3. Private receipt backup

Workflow: `.github/workflows/encrypted-receipt-backup.yml`

Runs weekly on Sunday at 10:30 Asia/Bangkok and can also be triggered manually.

It exports objects from the private `expense-receipts` bucket, creates an archive, encrypts it, deletes the unencrypted files, and uploads only the encrypted archive and checksum. Artifact retention is 14 days.

Required GitHub `production` environment secrets:

- `VITE_SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `BACKUP_PASSPHRASE`

`SUPABASE_SERVICE_ROLE_KEY` is server-only and bypasses RLS. Never expose it in Vite/browser code. Use it only as a protected GitHub environment secret for this backup workflow.

## 4. Recommended retention strategy on Supabase Free Plan

- Daily encrypted database backups: retain rolling 7 days in GitHub Actions
- Weekly encrypted receipt backups: retain rolling 14 days
- Once per month: download one encrypted database backup and one receipt backup to an offline/private location controlled by the owner
- Quarterly: perform a restore drill into a disposable database and verify key counts and financial totals

GitHub Actions artifacts are not the long-term archive. The monthly offline copy provides an additional recovery layer outside Supabase and outside the production application.

## 5. What the database backup does not replace

A PostgreSQL dump contains database data and schema, but it does not contain the binary contents of Supabase Storage objects. That is why receipt files are backed up separately.

The workflows also do not replace good operational controls: strong owner credentials, MFA on GitHub/Supabase administration accounts, RLS reviews, and periodic Security Advisor checks remain required.
