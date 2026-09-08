import {useEffect,useState} from 'react';
import {supabase} from '../lib/supabase';

type Totals={net:number;cogs:number;invoices:number;items:number;pending:number;missing:number};

export function SalesOverviewPage(){
 const[t,setT]=useState<Totals>({net:0,cogs:0,invoices:0,items:0,pending:0,missing:0});
 useEffect(()=>{void (async()=>{const[tx,si]=await Promise.all([supabase.from('sales_transactions').select('id,net_amount').neq('status','REVERSED'),supabase.from('sales_items').select('quantity,total_cost_snapshot,costing_status')]);const txs=tx.data??[],items=si.data??[];setT({net:txs.reduce((a,x)=>a+Number(x.net_amount||0),0),cogs:items.reduce((a,x)=>a+Number(x.total_cost_snapshot||0),0),invoices:txs.length,items:items.reduce((a,x)=>a+Number(x.quantity||0),0),pending:items.filter(x=>x.costing_status==='PENDING').length,missing:items.filter(x=>x.costing_status==='MISSING_COST'||x.costing_status==='ERROR').length})})()},[]);
 const gp=t.net-t.cogs;const margin=t.net>0?gp/t.net*100:0;
 return <><h1>Sales Overview</h1><p className="lead">Management sales and historical COGS based on cost snapshots recorded when inventory usage is processed.</p><div className="cards"><Card t="Net sales" v={`฿${t.net.toFixed(2)}`}/><Card t="COGS" v={`฿${t.cogs.toFixed(2)}`}/><Card t="Gross profit" v={`฿${gp.toFixed(2)}`}/><Card t="Gross margin" v={`${margin.toFixed(1)}%`}/><Card t="Invoices" v={String(t.invoices)}/><Card t="Items sold" v={String(t.items)}/></div>{(t.pending>0||t.missing>0)&&<div className="warn">COGS is incomplete: {t.pending} pending sales rows and {t.missing} rows missing cost basis or requiring review.</div>}<div className="panel"><h2>Interpretation</h2><p>Gross profit uses the historical cost snapshot stored on each sales item. Later ingredient price changes do not rewrite prior-period COGS.</p></div></>;
}

function Card({t,v}:{t:string;v:string}){return <div className="card"><small>{t}</small><strong>{v}</strong></div>}
