import { useCallback, useEffect, useMemo, useState } from 'react';
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
  quantity: number;
  total_cost_snapshot: number | null;
  costing_status: string;
};

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
  WALK_IN: 'หน้าร้าน',
  DINE_IN: 'ทานที่ร้าน',
  TAKEAWAY: 'ซื้อกลับ',
  DELIVERY: 'เดลิเวอรี',
  OTHER: 'อื่น ๆ',
};

const paymentLabel: Record<string, string> = {
  CASH: 'เงินสด',
  PROMPTPAY: 'พร้อมเพย์',
  CARD: 'บัตร',
  TRANSFER: 'โอนเงิน',
  OTHER: 'อื่น ๆ',
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
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [date, setDate] = useState('');

  const load = useCallback(async () => {
    setError('');
    const [salesResult, itemsResult] = await Promise.all([
      supabase
        .from('sales_transactions')
        .select('id,invoice_no,sold_at,sales_channel,payment_method,gross_amount,discount_amount,net_amount,status')
        .order('sold_at', { ascending: false })
        .limit(500),
      supabase
        .from('sales_items')
        .select('id,sales_transaction_id,quantity,total_cost_snapshot,costing_status')
        .order('created_at', { ascending: false })
        .limit(5000),
    ]);

    if (salesResult.error || itemsResult.error) {
      setError(uiError('โหลดรายการขายและต้นทุน'));
      return;
    }

    setRows((salesResult.data ?? []) as Sale[]);
    setItems((itemsResult.data ?? []) as SaleItem[]);
  }, []);

  useEffect(() => { void load(); }, [load]);

  const costByTransaction = useMemo(() => {
    const grouped = new Map<string, SaleItem[]>();
    for (const item of items) {
      const current = grouped.get(item.sales_transaction_id) ?? [];
      current.push(item);
      grouped.set(item.sales_transaction_id, current);
    }

    const summaries = new Map<string, CostSummary>();
    for (const [transactionId, saleItems] of grouped) {
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
  }, [items]);

  const filtered = useMemo(() => rows.filter(row => {
    if (date && row.sold_at.slice(0, 10) !== date) return false;
    if (query && !`${row.invoice_no} ${row.sales_channel ?? ''} ${row.payment_method ?? ''}`.toLowerCase().includes(query.toLowerCase())) return false;
    return true;
  }), [rows, date, query]);

  const totals = useMemo(() => filtered.reduce((acc, row) => {
    if (row.status === 'REVERSED') return acc;
    const summary = costByTransaction.get(row.id);
    acc.sales += Number(row.net_amount || 0);
    if (summary?.status === 'PROCESSED') {
      acc.cost += summary.cost;
      acc.complete += 1;
    } else {
      acc.incomplete += 1;
    }
    return acc;
  }, { sales: 0, cost: 0, complete: 0, incomplete: 0 }), [filtered, costByTransaction]);

  const grossProfit = totals.sales - totals.cost;
  const margin = totals.sales > 0 ? (grossProfit / totals.sales) * 100 : 0;

  return <>
    <div className="pagehead">
      <div>
        <h1>รายการขาย</h1>
        <p className="lead">แสดงยอดขาย ต้นทุนวัตถุดิบ และกำไรขั้นต้นต่อใบขายจากข้อมูลที่นำเข้าจาก GPOS และต้นทุนที่ระบบบันทึกตอนตัดสต็อก</p>
      </div>
      <button className="secondary" onClick={() => void load()}>รีเฟรช</button>
    </div>

    <div className="cards compact">
      <div className="card"><small>ยอดขายสุทธิ</small><strong>฿{totals.sales.toFixed(2)}</strong></div>
      <div className="card"><small>ต้นทุนขายที่คำนวณแล้ว</small><strong>฿{totals.cost.toFixed(2)}</strong></div>
      <div className="card"><small>กำไรขั้นต้น</small><strong>฿{grossProfit.toFixed(2)}</strong></div>
      <div className="card"><small>อัตรากำไรขั้นต้น</small><strong>{margin.toFixed(1)}%</strong></div>
    </div>

    <div className="panel">
      <div className="toolbar">
        <input type="date" value={date} onChange={e => setDate(e.target.value)} aria-label="วันที่ขาย" />
        <input placeholder="ค้นหาเลขที่ใบขาย ช่องทาง หรือวิธีชำระ..." value={query} onChange={e => setQuery(e.target.value)} />
      </div>
      {totals.incomplete > 0 && <div className="warn">มี {totals.incomplete} ใบขายที่ต้นทุนยังไม่ครบ กำไรของใบขายเหล่านี้จะยังไม่แสดงจนกว่าการตัดสต็อกและต้นทุนจะสมบูรณ์</div>}
      {error && <div className="warn">{error}</div>}

      <div className="tablewrap"><table><thead><tr>
        <th>วัน-เวลา</th>
        <th>เลขที่ใบขาย</th>
        <th>ช่องทางขาย</th>
        <th>วิธีชำระเงิน</th>
        <th>จำนวนสินค้า</th>
        <th>ยอดสุทธิ</th>
        <th>ต้นทุนขาย</th>
        <th>กำไรขั้นต้น</th>
        <th>% กำไรขั้นต้น</th>
        <th>สถานะต้นทุน</th>
        <th>สถานะใบขาย</th>
      </tr></thead><tbody>
        {filtered.map(row => {
          const summary = costByTransaction.get(row.id) ?? { itemCount: 0, quantity: 0, cost: 0, status: 'NO_ITEMS' as const };
          const complete = summary.status === 'PROCESSED';
          const profit = Number(row.net_amount) - summary.cost;
          const profitMargin = Number(row.net_amount) > 0 ? (profit / Number(row.net_amount)) * 100 : 0;
          return <tr key={row.id}>
            <td>{new Date(row.sold_at).toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' })}</td>
            <td><strong>{row.invoice_no}</strong></td>
            <td>{row.sales_channel ? (channelLabel[row.sales_channel] ?? row.sales_channel) : 'ยังไม่จับคู่'}</td>
            <td>{row.payment_method ? (paymentLabel[row.payment_method] ?? row.payment_method) : 'ยังไม่จับคู่'}</td>
            <td>{summary.quantity.toFixed(2)}</td>
            <td>฿{Number(row.net_amount).toFixed(2)}</td>
            <td>{complete ? `฿${summary.cost.toFixed(2)}` : '—'}</td>
            <td>{complete ? `฿${profit.toFixed(2)}` : '—'}</td>
            <td>{complete ? `${profitMargin.toFixed(1)}%` : '—'}</td>
            <td>{costingStatusLabel[summary.status]}</td>
            <td>{saleStatusLabel[row.status] ?? row.status}</td>
          </tr>;
        })}
        {filtered.length === 0 && <tr><td colSpan={11} className="empty">ไม่พบรายการขายตามเงื่อนไข</td></tr>}
      </tbody></table></div>
    </div>
  </>;
}
