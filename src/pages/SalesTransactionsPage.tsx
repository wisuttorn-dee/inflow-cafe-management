import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { uiError } from '../lib/ui';

type Sale = {
  id: string;
  invoice_no: string;
  sold_at: string;
  sales_channel: string | null;
  payment_method: string | null;
  gross_amount: number;
  discount_amount: number;
  net_amount: number;
  status: string;
};

type SaleItem = {
  id: string;
  sales_transaction_id: string;
  gpos_item_name: string;
  menu_item_id: string | null;
  quantity: number;
  net_amount: number;
  unit_cost_snapshot: number | null;
  total_cost_snapshot: number | null;
  costing_status: string;
};

type MenuItem = { id:string; name_th:string; name_en:string|null };

type CostSummary = {
  itemCount: number;
  quantity: number;
  cost: number;
  status: 'PROCESSED' | 'PENDING' | 'MISSING_COST' | 'ERROR' | 'NO_ITEMS';
};

const saleStatusLabel: Record<string, string> = {
  COMPLETED: 'สำเร็จ',
  REVERSED: 'ยกเลิกย้อนหลัง',
  ADJUSTED: 'ปรับปรุงแล้ว',
};

const channelLabel: Record<string, string> = {
  WALK_IN: 'หน้าร้าน', DINE_IN: 'ทานที่ร้าน', TAKEAWAY: 'ซื้อกลับ', DELIVERY: 'เดลิเวอรี', OTHER: 'อื่น ๆ',
};

const paymentLabel: Record<string, string> = {
  CASH: 'เงินสด', PROMPTPAY: 'พร้อมเพย์', CARD: 'บัตร', TRANSFER: 'โอนเงิน', OTHER: 'อื่น ๆ',
};

const costingStatusLabel: Record<CostSummary['status'], string> = {
  PROCESSED: 'ต้นทุนครบ',
  PENDING: 'รอตัดสต็อก',
  MISSING_COST: 'ต้นทุนไม่ครบ',
  ERROR: 'ต้องตรวจสอบ',
  NO_ITEMS: 'ไม่มีรายการสินค้า',
};

export function SalesTransactionsPage() {
  const [rows, setRows] = useState<Sale[]>([]);
  const [items, setItems] = useState<SaleItem[]>([]);
  const [menus, setMenus] = useState<MenuItem[]>([]);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [date, setDate] = useState('');
  const [selected, setSelected] = useState('');

  const load = useCallback(async () => {
    setError('');
    const [salesResult, itemsResult, menuResult] = await Promise.all([
      supabase.from('sales_transactions').select('id,invoice_no,sold_at,sales_channel,payment_method,gross_amount,discount_amount,net_amount,status').order('sold_at', { ascending: false }).limit(500),
      supabase.from('sales_items').select('id,sales_transaction_id,gpos_item_name,menu_item_id,quantity,net_amount,unit_cost_snapshot,total_cost_snapshot,costing_status').order('created_at', { ascending: false }).limit(5000),
      supabase.from('menu_items').select('id,name_th,name_en'),
    ]);
    if (salesResult.error || itemsResult.error || menuResult.error) {
      setError(uiError('โหลดรายการขายและต้นทุน'));
      return;
    }
    setRows((salesResult.data ?? []) as Sale[]);
    setItems((itemsResult.data ?? []) as SaleItem[]);
    setMenus((menuResult.data ?? []) as MenuItem[]);
  }, []);

  useEffect(() => { void load(); }, [load]);

  const menuMap = useMemo(() => new Map(menus.map(x => [x.id, x])), [menus]);
  const itemsByTransaction = useMemo(() => {
    const grouped = new Map<string, SaleItem[]>();
    for (const item of items) {
      const current = grouped.get(item.sales_transaction_id) ?? [];
      current.push(item);
      grouped.set(item.sales_transaction_id, current);
    }
    return grouped;
  }, [items]);

  const costByTransaction = useMemo(() => {
    const summaries = new Map<string, CostSummary>();
    for (const [transactionId, saleItems] of itemsByTransaction) {
      let status: CostSummary['status'] = 'PROCESSED';
      if (saleItems.some(x => x.costing_status === 'ERROR')) status = 'ERROR';
      else if (saleItems.some(x => x.costing_status === 'MISSING_COST')) status = 'MISSING_COST';
      else if (saleItems.some(x => x.costing_status !== 'PROCESSED')) status = 'PENDING';
      summaries.set(transactionId, {
        itemCount: saleItems.length,
        quantity: saleItems.reduce((sum, x) => sum + Number(x.quantity || 0), 0),
        cost: saleItems.reduce((sum, x) => sum + Number(x.total_cost_snapshot ?? 0), 0),
        status,
      });
    }
    return summaries;
  }, [itemsByTransaction]);

  const filtered = useMemo(() => rows.filter(row => {
    if (date && row.sold_at.slice(0, 10) !== date) return false;
    if (query && !`${row.invoice_no} ${row.sales_channel ?? ''} ${row.payment_method ?? ''}`.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  }), [rows, date, query]);

  const totals = useMemo(() => filtered.reduce((acc, row) => {
    if (row.status === 'REVERSED') return acc;
    const summary = costByTransaction.get(row.id);
    acc.sales += Number(row.net_amount || 0);
    if (summary?.status === 'PROCESSED') { acc.cost += summary.cost; acc.complete += 1; }
    else acc.incomplete += 1;
    return acc;
  }, { sales: 0, cost: 0, complete: 0, incomplete: 0 }), [filtered, costByTransaction]);

  const grossProfit = totals.sales - totals.cost;
  const margin = totals.sales > 0 ? (grossProfit / totals.sales) * 100 : 0;
  const selectedSale = rows.find(x => x.id === selected) ?? null;
  const selectedItems = selected ? (itemsByTransaction.get(selected) ?? []) : [];

  return <>
    <div className="pagehead"><div><h1>รายการขาย</h1><p className="lead">แสดงยอดขาย ต้นทุนวัตถุดิบ และกำไรขั้นต้นต่อใบขายจากข้อมูล GPOS และต้นทุนที่ระบบบันทึกตอนตัดสต็อก</p></div><button className="secondary" onClick={() => void load()}>รีเฟรช</button></div>

    <div className="cards compact">
      <div className="card"><small>ยอดขายสุทธิ</small><strong>฿{totals.sales.toFixed(2)}</strong></div>
      <div className="card"><small>ต้นทุนขายที่คำนวณแล้ว</small><strong>฿{totals.cost.toFixed(2)}</strong></div>
      <div className="card"><small>กำไรขั้นต้น</small><strong>฿{grossProfit.toFixed(2)}</strong></div>
      <div className="card"><small>อัตรากำไรขั้นต้น</small><strong>{margin.toFixed(1)}%</strong></div>
    </div>

    <div className="panel">
      <div className="toolbar"><input type="date" value={date} onChange={e => setDate(e.target.value)} aria-label="วันที่ขาย"/><input placeholder="ค้นหาเลขที่ใบขาย ช่องทาง หรือวิธีชำระ..." value={query} onChange={e => setQuery(e.target.value)}/></div>
      {totals.incomplete > 0 && <div className="warn">มี {totals.incomplete} ใบขายที่ต้นทุนยังไม่ครบ กำไรจะยังไม่แสดงจนกว่าการตัดสต็อกและต้นทุนจะสมบูรณ์</div>}
      {error && <div className="warn">{error}</div>}
      <div className="tablewrap"><table><thead><tr><th>วัน-เวลา</th><th>เลขที่ใบขาย</th><th>ช่องทางขาย</th><th>วิธีชำระเงิน</th><th>จำนวนสินค้า</th><th>ยอดสุทธิ</th><th>ต้นทุนขาย</th><th>กำไรขั้นต้น</th><th>% กำไรขั้นต้น</th><th>สถานะต้นทุน</th><th>สถานะใบขาย</th></tr></thead><tbody>
        {filtered.map(row => {
          const summary = costByTransaction.get(row.id) ?? { itemCount: 0, quantity: 0, cost: 0, status: 'NO_ITEMS' as const };
          const complete = summary.status === 'PROCESSED';
          const profit = Number(row.net_amount) - summary.cost;
          const profitMargin = Number(row.net_amount) > 0 ? (profit / Number(row.net_amount)) * 100 : 0;
          return <tr key={row.id}><td>{new Date(row.sold_at).toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' })}</td><td><button className="smallbtn" onClick={() => setSelected(row.id)}>{row.invoice_no}</button></td><td>{row.sales_channel ? (channelLabel[row.sales_channel] ?? row.sales_channel) : 'ยังไม่จับคู่'}</td><td>{row.payment_method ? (paymentLabel[row.payment_method] ?? row.payment_method) : 'ยังไม่จับคู่'}</td><td>{summary.quantity.toFixed(2)}</td><td>฿{Number(row.net_amount).toFixed(2)}</td><td>{complete ? `฿${summary.cost.toFixed(2)}` : '—'}</td><td>{complete ? `฿${profit.toFixed(2)}` : '—'}</td><td>{complete ? `${profitMargin.toFixed(1)}%` : '—'}</td><td>{costingStatusLabel[summary.status]}</td><td>{saleStatusLabel[row.status] ?? row.status}</td></tr>;
        })}
        {filtered.length === 0 && <tr><td colSpan={11} className="empty">ไม่พบรายการขายตามเงื่อนไข</td></tr>}
      </tbody></table></div>
    </div>

    {selectedSale && <div className="panel">
      <div className="pagehead"><div><h2>รายละเอียดใบขาย {selectedSale.invoice_no}</h2><p className="lead">แยกยอดขาย ต้นทุน และกำไรของแต่ละเมนูในใบขายนี้</p></div><Link className="smallbtn" to={`/inventory/sales-usage?invoice=${encodeURIComponent(selectedSale.invoice_no)}`}>ดูการตัดวัตถุดิบ</Link></div>
      <div className="tablewrap"><table><thead><tr><th>เมนู</th><th>จำนวน</th><th>ยอดขาย</th><th>ต้นทุน/หน่วย</th><th>ต้นทุนรวม</th><th>กำไรขั้นต้น</th><th>% กำไร</th><th>สถานะต้นทุน</th></tr></thead><tbody>
        {selectedItems.map(item => {
          const menu = item.menu_item_id ? menuMap.get(item.menu_item_id) : null;
          const menuName = menu?.name_th || menu?.name_en || item.gpos_item_name;
          const complete = item.costing_status === 'PROCESSED';
          const cost = Number(item.total_cost_snapshot ?? 0);
          const profit = Number(item.net_amount) - cost;
          const itemMargin = Number(item.net_amount) > 0 ? profit / Number(item.net_amount) * 100 : 0;
          return <tr key={item.id}><td><strong>{menuName}</strong>{menuName !== item.gpos_item_name && <small className="muted block">GPOS: {item.gpos_item_name}</small>}</td><td>{Number(item.quantity).toFixed(2)}</td><td>฿{Number(item.net_amount).toFixed(2)}</td><td>{complete && item.unit_cost_snapshot != null ? `฿${Number(item.unit_cost_snapshot).toFixed(2)}` : '—'}</td><td>{complete ? `฿${cost.toFixed(2)}` : '—'}</td><td>{complete ? `฿${profit.toFixed(2)}` : '—'}</td><td>{complete ? `${itemMargin.toFixed(1)}%` : '—'}</td><td>{costingStatusLabel[(item.costing_status in costingStatusLabel ? item.costing_status : 'ERROR') as CostSummary['status']]}</td></tr>;
        })}
        {selectedItems.length === 0 && <tr><td colSpan={8} className="empty">ไม่พบรายการสินค้าในใบขายนี้</td></tr>}
      </tbody></table></div>
    </div>}
  </>;
}
