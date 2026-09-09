import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

type Sale = { id:string; invoice_no:string; sold_at:string; sales_channel:string|null; payment_method:string|null; gross_amount:number; discount_amount:number; net_amount:number; status:string };
export function SalesTransactionsPage(){
 const[rows,setRows]=useState<Sale[]>([]);const[error,setError]=useState('');
 const load=useCallback(async()=>{const{data,error:e}=await supabase.from('sales_transactions').select('id,invoice_no,sold_at,sales_channel,payment_method,gross_amount,discount_amount,net_amount,status').order('sold_at',{ascending:false}).limit(200);if(e)setError(e.message);else setRows((data??[]) as Sale[])},[]);
 useEffect(()=>{void load()},[load]);
 return <><h1>รายการขาย</h1><p className="lead">รายการขายที่นำเข้าจาก GPOS หน้านี้ไม่ใช้สำหรับบันทึกการขายด้วยตนเอง</p>{error&&<div className="warn">{error}</div>}<div className="panel tablewrap"><table><thead><tr><th>วัน-เวลา</th><th>เลขที่ใบขาย</th><th>ช่องทางขาย</th><th>วิธีชำระเงิน</th><th>ยอดก่อนส่วนลด</th><th>ส่วนลด</th><th>ยอดสุทธิ</th><th>สถานะ</th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td>{new Date(r.sold_at).toLocaleString('th-TH',{timeZone:'Asia/Bangkok'})}</td><td>{r.invoice_no}</td><td>{r.sales_channel??'ยังไม่จับคู่'}</td><td>{r.payment_method??'ยังไม่จับคู่'}</td><td>฿{Number(r.gross_amount).toFixed(2)}</td><td>฿{Number(r.discount_amount).toFixed(2)}</td><td>฿{Number(r.net_amount).toFixed(2)}</td><td>{r.status}</td></tr>)}</tbody></table></div></>;
}
