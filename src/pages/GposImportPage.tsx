import { useMemo, useState } from 'react';
import { parseGposFile } from '../lib/gpos';
import { commitGposImport, normaliseProductName, prepareGposRows, type CommitResult, type PreparedGposRow } from '../lib/gposImport';
import { supabase } from '../lib/supabase';

type MenuItem = { id: string; name_th: string; name_en: string | null };
type PaymentMapping = { gpos_value: string; sales_channel: string; payment_method: string };

export function GposImportPage() {
  const [filename, setFilename] = useState('');
  const [rows, setRows] = useState<PreparedGposRow[]>([]);
  const [menus, setMenus] = useState<MenuItem[]>([]);
  const [payments, setPayments] = useState<PaymentMapping[]>([]);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [commitResult, setCommitResult] = useState<CommitResult | null>(null);

  async function refreshMappings(sourceRows = rows) {
    const { data: menuData, error: menuError } = await supabase
      .from('menu_items').select('id,name_th,name_en').eq('is_active', true).order('name_th');
    if (menuError) throw menuError;
    setMenus((menuData ?? []) as MenuItem[]);

    const paymentValues = [...new Set(sourceRows.map(r => r.payment).filter(Boolean))];
    if (paymentValues.length) {
      const { data: payData, error: payError } = await supabase
        .from('payment_channel_mapping')
        .select('gpos_value,sales_channel,payment_method')
        .eq('is_active', true)
        .in('gpos_value', paymentValues);
      if (payError) throw payError;
      setPayments((payData ?? []) as PaymentMapping[]);
    } else setPayments([]);
  }

  async function choose(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setBusy(true); setError(''); setMessage(''); setCommitResult(null); setFilename(file.name);
    try {
      const parsed = await parseGposFile(file);
      const prepared = await prepareGposRows(parsed.rows, parsed.hashes);
      setRows(prepared);
      await refreshMappings(prepared);
    } catch (err) {
      setRows([]);
      setError(err instanceof Error ? err.message : 'เตรียมไฟล์ GPOS ไม่สำเร็จ');
    } finally { setBusy(false); }
  }

  const summary = useMemo(() => {
    const valid = rows.filter(r => r.errors.length === 0);
    const duplicate = valid.filter(r => r.duplicate);
    const ready = valid.filter(r => !r.duplicate);
    const unmapped = ready.filter(r => !r.mappedMenuItemId);
    return {
      source: rows.length,
      invalid: rows.filter(r => r.errors.length > 0).length,
      duplicate: duplicate.length,
      ready: ready.length,
      unmapped: unmapped.length,
      net: ready.reduce((sum, r) => sum + r.total, 0),
    };
  }, [rows]);

  const unmappedProducts = useMemo(() => {
    const seen = new Set<string>();
    return rows.filter(r => !r.duplicate && r.errors.length === 0 && !r.mappedMenuItemId).filter(r => {
      if (seen.has(r.normalisedItemName)) return false;
      seen.add(r.normalisedItemName); return true;
    });
  }, [rows]);

  const unmappedPayments = useMemo(() => {
    const mapped = new Set(payments.map(p => p.gpos_value));
    return [...new Set(rows.filter(r => !r.duplicate && r.errors.length === 0).map(r => r.payment).filter(Boolean))]
      .filter(value => !mapped.has(value));
  }, [rows, payments]);

  async function saveProductMapping(itemName: string, menuItemId: string) {
    if (!menuItemId) return;
    setError('');
    const normalised = normaliseProductName(itemName);
    const { error: upsertError } = await supabase.from('gpos_product_mapping').upsert({
      source_system: 'GPOS', external_item_name: itemName, normalised_item_name: normalised,
      menu_item_id: menuItemId, is_active: true,
    }, { onConflict: 'source_system,normalised_item_name' });
    if (upsertError) { setError(`บันทึกการจับคู่สินค้าไม่สำเร็จ: ${upsertError.message}`); return; }
    setRows(current => current.map(r => r.normalisedItemName === normalised ? { ...r, mappedMenuItemId: menuItemId } : r));
    setMessage(`จับคู่ ${itemName} แล้ว`);
  }

  async function savePaymentMapping(gposValue: string, salesChannel: string, paymentMethod: string) {
    const { error: upsertError } = await supabase.from('payment_channel_mapping').upsert({
      gpos_value: gposValue, sales_channel: salesChannel, payment_method: paymentMethod, is_active: true,
    }, { onConflict: 'gpos_value' });
    if (upsertError) { setError(`บันทึกการจับคู่การชำระเงินไม่สำเร็จ: ${upsertError.message}`); return; }
    await refreshMappings(rows);
    setMessage(`จับคู่การชำระเงิน ${gposValue} แล้ว`);
  }

  async function confirmImport() {
    if (!filename || !rows.length || summary.invalid > 0 || summary.ready === 0) return;
    setBusy(true); setError(''); setMessage('');
    try {
      const result = await commitGposImport(filename, rows);
      setCommitResult(result);
      setMessage(`นำเข้าสำเร็จ: ${result.imported_rows} รายการใหม่, ข้ามรายการซ้ำ ${result.duplicate_rows} รายการ`);
      const prepared = await prepareGposRows(rows, rows.map(r => r.sourceRowHash));
      setRows(prepared);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'นำเข้าไม่สำเร็จ');
    } finally { setBusy(false); }
  }

  return <>
    <h1>นำเข้าข้อมูล GPOS</h1>
    <p className="lead">อัปโหลด ตรวจสอบ จับคู่ และยืนยันข้อมูลยอดขายจาก GPOS</p>
    <div className="panel">
      <input type="file" accept=".xlsx" onChange={e => void choose(e)} disabled={busy} />
      {busy && <p>กำลังประมวลผล…</p>}
      {error && <div className="warn">{error}</div>}
      {message && <p>{message}</p>}
      {rows.length > 0 && <>
        <div className="cards compact">
          <Metric title="รายการจากไฟล์" value={summary.source} />
          <Metric title="พร้อมนำเข้า" value={summary.ready} />
          <Metric title="รายการซ้ำ" value={summary.duplicate} />
          <Metric title="ข้อมูลไม่ถูกต้อง" value={summary.invalid} />
          <Metric title="สินค้ายังไม่จับคู่" value={summary.unmapped} />
          <Metric title="ยอดขายสุทธิใหม่" value={`฿${summary.net.toFixed(2)}`} />
        </div>

        {unmappedProducts.length > 0 && <section>
          <h2>จับคู่สินค้า</h2>
          <p>สินค้าที่ยังไม่จับคู่สามารถนำเข้าได้ แต่ต้นทุนและการตัดสต็อกจะยังไม่สมบูรณ์จนกว่าจะจับคู่เมนูเรียบร้อย</p>
          <div className="tablewrap"><table><thead><tr><th>สินค้าใน GPOS</th><th>จับคู่กับเมนู INFLOW</th></tr></thead><tbody>
            {unmappedProducts.map(row => <MappingRow key={row.normalisedItemName} row={row} menus={menus} onSave={saveProductMapping} />)}
          </tbody></table></div>
        </section>}

        {unmappedPayments.length > 0 && <section>
          <h2>จับคู่การชำระเงิน</h2>
          <div className="tablewrap"><table><thead><tr><th>การชำระเงินใน GPOS</th><th>ช่องทางขาย</th><th>วิธีชำระเงิน</th><th>จัดการ</th></tr></thead><tbody>
            {unmappedPayments.map(value => <PaymentRow key={value} value={value} onSave={savePaymentMapping} />)}
          </tbody></table></div>
        </section>}

        <h2>ตัวอย่างข้อมูลก่อนนำเข้า</h2>
        <div className="tablewrap"><table><thead><tr>{['สถานะ','วัน-เวลา','เลขที่ใบขาย','สินค้า','จำนวน','ราคาต่อหน่วย','ส่วนลด','ยอดรวม','การชำระเงิน'].map(h => <th key={h}>{h}</th>)}</tr></thead><tbody>
          {rows.slice(0, 150).map((r, i) => <tr key={`${r.sourceRowHash}-${i}`} className={r.errors.length ? 'bad' : ''}>
            <td>{r.errors.length ? 'ผิดพลาด' : r.duplicate ? 'รายการซ้ำ' : r.mappedMenuItemId ? 'พร้อม' : 'พร้อม / ยังไม่จับคู่'}</td>
            <td>{r.dateTime}</td><td>{r.invoiceNo}</td><td>{r.itemName}</td><td>{r.qty}</td><td>{r.unitPrice}</td><td>{r.discount}</td><td>{r.total}</td><td>{r.payment}</td>
          </tr>)}
        </tbody></table></div>

        {summary.invalid > 0 && <div className="warn">กรุณาแก้ข้อมูลที่ไม่ถูกต้องก่อนยืนยันการนำเข้า</div>}
        <button onClick={() => void confirmImport()} disabled={busy || summary.invalid > 0 || summary.ready === 0}>ยืนยันการนำเข้า</button>
      </>}
      {commitResult && <div className="panel"><strong>รหัสการนำเข้า:</strong> {commitResult.import_id}<br />นำเข้า {commitResult.imported_rows} รายการ, ซ้ำ {commitResult.duplicate_rows} รายการ, ยังไม่จับคู่ {commitResult.unmapped_rows} รายการ, ยอดสุทธิ ฿{Number(commitResult.net_sales).toFixed(2)}</div>}
    </div>
  </>;
}

function Metric({ title, value }: { title: string; value: string | number }) {
  return <div className="card"><small>{title}</small><strong>{value}</strong></div>;
}

function MappingRow({ row, menus, onSave }: { row: PreparedGposRow; menus: MenuItem[]; onSave: (name: string, menuId: string) => Promise<void> }) {
  const [menuId, setMenuId] = useState('');
  return <tr><td>{row.itemName}</td><td><select value={menuId} onChange={e => setMenuId(e.target.value)}><option value="">เลือกเมนูสินค้า</option>{menus.map(m => <option key={m.id} value={m.id}>{m.name_th}{m.name_en ? ` / ${m.name_en}` : ''}</option>)}</select> <button className="smallbtn" disabled={!menuId} onClick={() => void onSave(row.itemName, menuId)}>บันทึก</button></td></tr>;
}

function PaymentRow({ value, onSave }: { value: string; onSave: (value: string, channel: string, method: string) => Promise<void> }) {
  const [channel, setChannel] = useState('WALK_IN');
  const [method, setMethod] = useState(value.toLowerCase().includes('prompt') ? 'PROMPTPAY' : 'CASH');
  return <tr><td>{value}</td><td><select value={channel} onChange={e => setChannel(e.target.value)}><option>WALK_IN</option><option>GRABFOOD</option><option>LINEMAN</option><option>OTHER</option></select></td><td><select value={method} onChange={e => setMethod(e.target.value)}><option>CASH</option><option>PROMPTPAY</option><option>CARD</option><option>PLATFORM</option><option>OTHER</option></select></td><td><button className="smallbtn" onClick={() => void onSave(value, channel, method)}>บันทึก</button></td></tr>;
}
