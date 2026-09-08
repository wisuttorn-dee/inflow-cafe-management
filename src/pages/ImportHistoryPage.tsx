import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

type ImportRow = {
  id: string; original_filename: string; started_at: string; completed_at: string | null;
  total_source_rows: number; imported_rows: number; duplicate_rows: number; rejected_rows: number;
  unmapped_rows: number; net_sales: number; status: string;
};

export function ImportHistoryPage() {
  const [rows, setRows] = useState<ImportRow[]>([]);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    const { data, error: loadError } = await supabase.from('gpos_imports').select('id,original_filename,started_at,completed_at,total_source_rows,imported_rows,duplicate_rows,rejected_rows,unmapped_rows,net_sales,status').order('started_at', { ascending: false }).limit(100);
    if (loadError) setError(loadError.message); else setRows((data ?? []) as ImportRow[]);
  }, []);
  useEffect(() => { void load(); }, [load]);
  return <><h1>Import History</h1><p className="lead">Audit trail of committed GPOS imports. Phase 2 does not delete historical imports.</p>{error && <div className="warn">{error}</div>}<div className="panel tablewrap"><table><thead><tr><th>Date</th><th>File</th><th>Status</th><th>Source</th><th>Imported</th><th>Duplicates</th><th>Rejected</th><th>Unmapped</th><th>Net Sales</th><th>Import ID</th></tr></thead><tbody>{rows.map(r => <tr key={r.id}><td>{new Date(r.started_at).toLocaleString('en-GB',{timeZone:'Asia/Bangkok'})}</td><td>{r.original_filename}</td><td>{r.status}</td><td>{r.total_source_rows}</td><td>{r.imported_rows}</td><td>{r.duplicate_rows}</td><td>{r.rejected_rows}</td><td>{r.unmapped_rows}</td><td>฿{Number(r.net_sales).toFixed(2)}</td><td><code>{r.id.slice(0,8)}…</code></td></tr>)}</tbody></table></div></>;
}
