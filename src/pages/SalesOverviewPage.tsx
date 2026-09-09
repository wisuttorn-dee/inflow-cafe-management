import {useEffect,useState} from 'react';
import {supabase} from '../lib/supabase';

type Totals={net:number;cogs:number;invoices:number;items:number;pending:number;missing:number};

export function SalesOverviewPage(){
 const[t,setT]=useState<Totals>({net:0,cogs:0,invoices:0,items:0,pending:0,missing:0});
 useEffect(()=>{void (async()=>{const[tx,si]=await Promise.all([supabase.from('sales_transactions').select('id,net_amount').neq('status','REVERSED'),supabase.from('sales_items').select('quantity,total_cost_snapshot,costing_status')]);const txs=tx.data??[],items=si.data??[];setT({net:txs.reduce((a,x)=>a+Number(x.net_amount||0),0),cogs:items.reduce((a,x)=>a+Number(x.total_cost_snapshot||0),0),invoices:txs.length,items:items.reduce((a,x)=>a+Number(x.quantity||0),0),pending:items.filter(x=>x.costing_status==='PENDING').length,missing:items.filter(x=>x.costing_status==='MISSING_COST'||x.costing_status==='ERROR').length})})()},[]);
 const gp=t.net-t.cogs;const margin=t.net>0?gp/t.net*100:0;
 return <><h1>ภาพรวมยอดขาย</h1><p className="lead">สรุปยอดขายและต้นทุนขายย้อนหลังจากต้นทุนที่ถูกบันทึก ณ วันที่ระบบประมวลผลการใช้วัตถุดิบ</p><div className="cards"><Card t="ยอดขายสุทธิ" v={`฿${t.net.toFixed(2)}`}/><Card t="ต้นทุนขาย (COGS)" v={`฿${t.cogs.toFixed(2)}`}/><Card t="กำไรขั้นต้น" v={`฿${gp.toFixed(2)}`}/><Card t="อัตรากำไรขั้นต้น" v={`${margin.toFixed(1)}%`}/><Card t="จำนวนใบขาย" v={String(t.invoices)}/><Card t="จำนวนสินค้าที่ขาย" v={String(t.items)}/></div>{(t.pending>0||t.missing>0)&&<div className="warn">ข้อมูลต้นทุนขายยังไม่ครบ: มี {t.pending} รายการที่รอประมวลผล และ {t.missing} รายการที่ขาดต้นทุนหรือจำเป็นต้องตรวจสอบ</div>}<div className="panel"><h2>การตีความ</h2><p>กำไรขั้นต้นใช้ต้นทุนย้อนหลังที่เก็บไว้กับแต่ละรายการขาย ดังนั้นการเปลี่ยนราคาวัตถุดิบภายหลังจะไม่ย้อนกลับไปแก้ต้นทุนขายของงวดก่อน</p></div></>;
}

function Card({t,v}:{t:string;v:string}){return <div className="card"><small>{t}</small><strong>{v}</strong></div>}
