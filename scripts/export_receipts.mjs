import { createClient } from '@supabase/supabase-js';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const url = process.env.VITE_SUPABASE_URL;
const serviceRole = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceRole) throw new Error('Missing VITE_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');

const supabase = createClient(url, serviceRole, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const bucket = 'expense-receipts';
const root = 'backup/receipts';
await mkdir(root, { recursive: true });

const { data: folders, error: folderError } = await supabase.storage.from(bucket).list('', { limit: 1000 });
if (folderError) throw folderError;

let count = 0;
for (const folder of folders ?? []) {
  if (folder.id) {
    // Root-level file, supported defensively.
    const objectPath = folder.name;
    const { data, error } = await supabase.storage.from(bucket).download(objectPath);
    if (error) throw error;
    await writeFile(path.join(root, folder.name), Buffer.from(await data.arrayBuffer()));
    count += 1;
    continue;
  }

  const userDir = folder.name;
  const { data: files, error: fileError } = await supabase.storage.from(bucket).list(userDir, { limit: 1000 });
  if (fileError) throw fileError;
  await mkdir(path.join(root, userDir), { recursive: true });

  for (const file of files ?? []) {
    if (!file.id) continue;
    const objectPath = `${userDir}/${file.name}`;
    const { data, error } = await supabase.storage.from(bucket).download(objectPath);
    if (error) throw error;
    await writeFile(path.join(root, userDir, file.name), Buffer.from(await data.arrayBuffer()));
    count += 1;
  }
}

console.log(`Exported ${count} receipt object(s) from ${bucket}`);
