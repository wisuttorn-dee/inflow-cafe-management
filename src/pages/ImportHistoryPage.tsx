import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { uiError } from '../lib/ui';

type ImportRow = {
  id: string; original_filename: string; started_at: string; completed_at: string | null;
  total_source_rows: number; imported_rows: number; duplicate_rows: number; rejected_rows: number;
  unmapped_rows: number; net_sales: number; status: string;
};

const statusLabel:Record<string,string>={PREVIEW:'รอตรวจสอบ',PROCESSING:'กำลังนำเข้า',COMPLETED:'สำเร็จ',FAILED:'ไม่สำเร็จ',PARTIAL:'สำเร็จบางส่วน',REVERSED:'ยกเลิกย้อนหลัง'};

export function ImportHistoryPage() {
  const [rows, setRows] = useState<ImportRow[]>([]);
  const [error, setError] = useState('');
  const load = useCallback(async () => {
    setError('');
    const { data, error: loadError } = await supabase.from('gpos_imports').select('id,original_filename,started_at,completed_at,total_source_rows,imported_rows,duplicate_rows,rejected_rows,unmapped_rows,net_sales,status').order('started_at', { ascending: false }).limit(100);
    if (loadError) setError(uiError('โหลดประวัติการนำเข้า')); else setRows((data ?? []) as ImportRow[]);
  }, []);
  useEffect(() => { void load(); }, [load]);
  return <><div className="pagehead"><div><h1>ประวัติการนำเข้า</h1><p className="lead">ประวัติการนำเข้าข้อมูลขายจาก GPOS เพื่อใช้ตรวจสอบย้อนหลัง โดยระบบจะไม่ลบประวัติการนำเข้าเดิม</p></div><button className="secondary" onClick={()=>void load()}>รีเฟรช</button></div>{error && <div className="warn">{error}</div>}<div className="panel tablewrap"><table><thead><tr><th>วัน-เวลา</th><th>ชื่อไฟล์</th><th>สถานะ</th><th>จำนวนจากไฟล์</th><th>นำเข้าสำเร็จ</th><th>รายการซ้ำ</th><th>ปฏิเสธ</th><th>ยังไม่จับคู่</th><th>ยอดขายสุทธิ</th><th>รหัสการนำเข้า</th></tr></thead><tbody>{rows.map(r => <tr key={r.id}><td>{new Date(r.started_at).toLocaleString('th-TH',{timeZone:'Asia/Bangkok'})}</td><td>{r.original_filename}</td><td>{statusLabel[r.status]??'ต้องตรวจสอบ'}</td><td>{r.total_source_rows}</td><td>{r.imported_rows}</td><td>{r.duplicate_rows}</td><td>{r.rejected_rows}</td><td>{r.unmapped_rows}</td><td>฿{Number(r.net_sales).toFixed(2)}</td><td><code>{r.id.slice(0,8)}…</code></td></tr>)}{rows.length===0&&<tr><td colSpan={10} className="empty">ยังไม่มีประวัติการนำเข้า</td></tr>}</tbody></table></div></>;
}
