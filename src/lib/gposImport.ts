import { supabase } from './supabase';
import type { GposRow } from './gpos';

export type PreparedGposRow = GposRow & {
  sourceRowHash: string;
  normalisedItemName: string;
  duplicate: boolean;
  mappedMenuItemId: string | null;
};

export type CommitResult = {
  import_id: string;
  status: 'COMPLETED' | 'PARTIAL';
  total_source_rows: number;
  imported_rows: number;
  duplicate_rows: number;
  rejected_rows: number;
  unmapped_rows: number;
  gross_sales: number;
  total_discount: number;
  net_sales: number;
};

export const normaliseProductName = (value: string) =>
  value.trim().toLocaleLowerCase('th-TH').replace(/\s+/g, ' ');

export async function prepareGposRows(rows: GposRow[], hashes: string[]) {
  const duplicateHashes = new Set<string>();
  for (let i = 0; i < hashes.length; i += 200) {
    const batch = hashes.slice(i, i + 200);
    const { data, error } = await supabase.rpc('check_gpos_duplicate_hashes', { p_hashes: batch });
    if (error) throw error;
    for (const item of (data ?? []) as { source_row_hash: string }[]) duplicateHashes.add(item.source_row_hash);
  }

  const names = [...new Set(rows.map(r => normaliseProductName(r.itemName)).filter(Boolean))];
  const mappingByName = new Map<string, string>();
  if (names.length) {
    const { data, error } = await supabase
      .from('gpos_product_mapping')
      .select('normalised_item_name,menu_item_id')
      .eq('source_system', 'GPOS')
      .eq('is_active', true)
      .in('normalised_item_name', names);
    if (error) throw error;
    for (const item of (data ?? []) as { normalised_item_name: string; menu_item_id: string }[]) {
      mappingByName.set(item.normalised_item_name, item.menu_item_id);
    }
  }

  return rows.map((row, index): PreparedGposRow => {
    const normalisedItemName = normaliseProductName(row.itemName);
    return {
      ...row,
      sourceRowHash: hashes[index] ?? '',
      normalisedItemName,
      duplicate: duplicateHashes.has(hashes[index] ?? ''),
      mappedMenuItemId: mappingByName.get(normalisedItemName) ?? null,
    };
  });
}

export async function commitGposImport(filename: string, rows: PreparedGposRow[]) {
  const payload = rows.map(row => ({
    date_time: row.dateTime,
    invoice_no: row.invoiceNo,
    category: row.category,
    item_name: row.itemName,
    qty: row.qty,
    unit_price: row.unitPrice,
    discount: row.discount,
    total: row.total,
    payment: row.payment,
    source_row_hash: row.sourceRowHash,
    normalised_item_name: row.normalisedItemName,
  }));
  const { data, error } = await supabase.rpc('commit_gpos_import', {
    p_filename: filename,
    p_rows: payload,
  });
  if (error) throw error;
  return data as CommitResult;
}
