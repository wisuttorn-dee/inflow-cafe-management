import { readSheet } from 'read-excel-file/browser';

export const GPOS_FIELDS={dateTime:['วันที่-เวลา (Date-Time)','Date-Time'],invoiceNo:['เลขที่บิล (Invoice No.)','Invoice No.'],category:['หมวดหมู่ (Category)','Category'],itemName:['ชื่อสินค้า (Item Name)','Item Name'],qty:['จำนวน (Qty)','Qty'],unitPrice:['ราคาต่อหน่วย (Unit Price)','Unit Price'],discount:['ส่วนลด (Discount)','Discount'],total:['ยอดรวมสุทธิ (Total)','Total'],payment:['ช่องทางการชำระเงิน (Payment)','Payment']} as const;
export type GposRow={dateTime:string;invoiceNo:string;category:string;itemName:string;qty:number;unitPrice:number;discount:number;total:number;payment:string;errors:string[]};

type CellValue=string|number|boolean|Date|null|undefined;
const formatDate=(value:Date)=>{const pad=(n:number)=>String(n).padStart(2,'0');return `${value.getFullYear()}-${pad(value.getMonth()+1)}-${pad(value.getDate())} ${pad(value.getHours())}:${pad(value.getMinutes())}:${pad(value.getSeconds())}`};
const text=(value:CellValue)=>value instanceof Date?formatDate(value):String(value??'').trim();
const num=(value:CellValue)=>typeof value==='number'?value:Number(value??0);

export async function hashSourceRow(r:GposRow){const normalized=['GPOS',r.invoiceNo,r.dateTime,r.itemName.trim().toLocaleLowerCase('th-TH'),r.qty,r.unitPrice,r.discount,r.total].join('|');const buf=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(normalized));return [...new Uint8Array(buf)].map(b=>b.toString(16).padStart(2,'0')).join('');}

export async function parseGposFile(file:File){
 const data=await readSheet(file) as CellValue[][];
 if(data.length===0)throw new Error('Workbook has no data.');
 const headers=(data[0]??[]).map(text);
 const indexOf=(aliases:readonly string[])=>aliases.map(alias=>headers.indexOf(alias)).find(index=>index>=0)??-1;
 const indexes={dateTime:indexOf(GPOS_FIELDS.dateTime),invoiceNo:indexOf(GPOS_FIELDS.invoiceNo),category:indexOf(GPOS_FIELDS.category),itemName:indexOf(GPOS_FIELDS.itemName),qty:indexOf(GPOS_FIELDS.qty),unitPrice:indexOf(GPOS_FIELDS.unitPrice),discount:indexOf(GPOS_FIELDS.discount),total:indexOf(GPOS_FIELDS.total),payment:indexOf(GPOS_FIELDS.payment)};
 const required=['dateTime','invoiceNo','itemName','qty','unitPrice','total'] as const;
 const missing=required.filter(key=>indexes[key]<0);
 if(missing.length)throw new Error(`Missing required columns: ${missing.join(', ')}`);
 const value=(row:CellValue[],index:number)=>index>=0?row[index]:null;
 const rows:GposRow[]=data.slice(1).filter(row=>row.some(cell=>cell!==null&&cell!==undefined&&String(cell).trim()!=='')).map(row=>{
  const r:GposRow={dateTime:text(value(row,indexes.dateTime)),invoiceNo:text(value(row,indexes.invoiceNo)),category:text(value(row,indexes.category)),itemName:text(value(row,indexes.itemName)),qty:num(value(row,indexes.qty)),unitPrice:num(value(row,indexes.unitPrice)),discount:num(value(row,indexes.discount)),total:num(value(row,indexes.total)),payment:text(value(row,indexes.payment)),errors:[]};
  if(!r.dateTime)r.errors.push('Missing date/time');if(!r.invoiceNo)r.errors.push('Missing invoice number');if(!r.itemName)r.errors.push('Missing item name');if(!(r.qty>0))r.errors.push('Qty must be greater than zero');if(r.unitPrice<0)r.errors.push('Unit price cannot be negative');if(r.discount<0)r.errors.push('Discount cannot be negative');if(r.total<0)r.errors.push('Total cannot be negative');const expected=r.qty*r.unitPrice-r.discount;if(Math.abs(expected-r.total)>0.05)r.errors.push(`Total mismatch (expected ${expected.toFixed(2)})`);return r;
 });
 const hashes=await Promise.all(rows.map(hashSourceRow));
 return {rows,hashes,summary:{sourceRows:rows.length,uniqueInvoices:new Set(rows.map(r=>r.invoiceNo)).size,quantitySold:rows.reduce((a,r)=>a+r.qty,0),grossSales:rows.reduce((a,r)=>a+r.qty*r.unitPrice,0),discounts:rows.reduce((a,r)=>a+r.discount,0),netSales:rows.reduce((a,r)=>a+r.total,0),invalidRows:rows.filter(r=>r.errors.length>0).length}};
}
