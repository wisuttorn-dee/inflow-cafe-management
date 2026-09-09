import { useCallback, useEffect, useState } from 'react';
import { Route, Routes } from 'react-router-dom';
import { Menu } from 'lucide-react';
import { supabase, isSupabaseConfigured } from './lib/supabase';
import { Sidebar } from './components/Sidebar';
import { GposImportPage } from './pages/GposImportPage';
import { ImportHistoryPage } from './pages/ImportHistoryPage';
import { SalesTransactionsPage } from './pages/SalesTransactionsPage';
import { RecipePage } from './pages/RecipePage';
import { InventoryPage } from './pages/InventoryPage';
import { SalesOverviewPage } from './pages/SalesOverviewPage';
import { PurchasesPage } from './pages/PurchasesPage';
import { StockMovementsPage } from './pages/StockMovementsPage';
import { StockCountPage } from './pages/StockCountPage';
import { SalesInventoryUsagePage } from './pages/SalesInventoryUsagePage';
import { WastePage } from './pages/WastePage';
import { ExpensesPage } from './pages/ExpensesPage';
import { ManagementDashboardPage } from './pages/ManagementDashboardPage';
import { LowStockPage } from './pages/LowStockPage';
import { UserManagementPage } from './pages/UserManagementPage';

const sections = [
  ['แดชบอร์ด','/'],['ภาพรวมยอดขาย','/sales'],['รายการขาย','/sales/transactions'],['นำเข้า GPOS','/sales/import'],['ประวัตินำเข้า','/sales/import-history'],
  ['เมนูสินค้า','/menu'],['สูตรเครื่องดื่ม','/recipes'],['ต้นทุนสูตร','/recipe-costing'],['ภาพรวมสต็อก','/inventory'],['ตัดสต็อกจากยอดขาย','/inventory/sales-usage'],['ความเคลื่อนไหวสต็อก','/inventory/movements'],
  ['ตรวจนับสต็อก','/inventory/count'],['ของเสีย','/inventory/waste'],['วัตถุดิบใกล้หมด','/inventory/low'],['จัดซื้อ','/purchasing'],['ซัพพลายเออร์','/suppliers'],
  ['ค่าใช้จ่าย','/expenses'],['รายงานกำไร','/reports'],['หน่วยนับ','/settings/units'],['หมวดเมนู','/settings/categories'],['วัตถุดิบ','/ingredients'],['ผู้ใช้งาน','/settings/users'],['ตั้งค่า','/settings']
] as const;

const fieldLabels: Record<string,string> = {
  name_th: 'ชื่อภาษาไทย',
  name_en: 'ชื่อภาษาอังกฤษ',
  display_order: 'ลำดับการแสดงผล',
  selling_price: 'ราคาขาย',
  supplier_name: 'ชื่อซัพพลายเออร์',
  phone: 'เบอร์โทรศัพท์',
  email: 'อีเมล',
  code: 'รหัสหน่วย',
  unit_type: 'ประเภทหน่วย',
  ingredient_code: 'รหัสวัตถุดิบ',
  base_unit_id: 'หน่วยฐาน',
};

function fieldLabel(field:string){return fieldLabels[field] ?? field}

function Shell(){
  const[navOpen,setNavOpen]=useState(false);
  return <div className="app">
    <button className="menutoggle" onClick={()=>setNavOpen(v=>!v)} aria-label="เปิดเมนู"><Menu size={20}/></button>
    {navOpen&&<button className="sidebarBackdrop" onClick={()=>setNavOpen(false)} aria-label="ปิดเมนู"/>}
    <Sidebar open={navOpen} onNavigate={()=>setNavOpen(false)}/>
    <main className="appMain"><Routes>
      <Route path="/" element={<Dashboard/>}/><Route path="/sales" element={<SalesOverviewPage/>}/><Route path="/sales/transactions" element={<SalesTransactionsPage/>}/><Route path="/sales/import" element={<GposImportPage/>}/><Route path="/sales/import-history" element={<ImportHistoryPage/>}/><Route path="/recipes" element={<RecipePage/>}/><Route path="/recipe-costing" element={<SalesOverviewPage/>}/><Route path="/inventory" element={<InventoryPage/>}/><Route path="/inventory/sales-usage" element={<SalesInventoryUsagePage/>}/><Route path="/inventory/movements" element={<StockMovementsPage/>}/><Route path="/inventory/count" element={<StockCountPage/>}/><Route path="/inventory/waste" element={<WastePage/>}/><Route path="/inventory/low" element={<LowStockPage/>}/><Route path="/purchasing" element={<PurchasesPage/>}/><Route path="/expenses" element={<ExpensesPage/>}/><Route path="/reports" element={<ManagementDashboardPage/>}/><Route path="/settings/users" element={<UserManagementPage/>}/>
      <Route path="/menu" element={<MasterData title="เมนูสินค้า" table="menu_items" fields={['name_th','name_en','selling_price']}/>}/><Route path="/suppliers" element={<MasterData title="ซัพพลายเออร์" table="suppliers" fields={['supplier_name','phone','email']}/>}/><Route path="/settings/units" element={<MasterData title="หน่วยนับ" table="units" fields={['code','name_th','name_en','unit_type']}/>}/><Route path="/settings/categories" element={<MasterData title="หมวดเมนู" table="menu_categories" fields={['name_th','name_en','display_order']}/>}/><Route path="/ingredients" element={<MasterData title="วัตถุดิบ" table="ingredients" fields={['ingredient_code','name_th','name_en','base_unit_id']}/>}/><Route path="/settings" element={<Settings/>}/>
      {sections.filter(([,p])=>!['/','/sales','/sales/transactions','/sales/import','/sales/import-history','/recipes','/recipe-costing','/inventory','/inventory/sales-usage','/inventory/movements','/inventory/count','/inventory/waste','/inventory/low','/purchasing','/expenses','/reports','/settings/users','/menu','/suppliers','/settings','/settings/units','/settings/categories','/ingredients'].includes(p)).map(([n,p])=><Route key={p} path={p} element={<ComingSoon title={n}/>}/>)}</Routes></main>
  </div>
}

function Login(){const[email,setEmail]=useState('');const[password,setPassword]=useState('');const[msg,setMsg]=useState('');async function submit(e:React.FormEvent){e.preventDefault();const{error}=await supabase.auth.signInWithPassword({email,password});setMsg(error?.message??'');}return <div className="login"><form onSubmit={submit}><div className="brand dark">INFLOW<span>ระบบบริหาร INFLOW Riverside Café</span></div>{!isSupabaseConfigured&&<div className="warn">กรุณาตั้งค่า Supabase environment variables ก่อนใช้งาน</div>}<input type="email" placeholder="อีเมล" value={email} onChange={e=>setEmail(e.target.value)} required/><input type="password" placeholder="รหัสผ่าน" value={password} onChange={e=>setPassword(e.target.value)} required/><button>เข้าสู่ระบบ</button>{msg&&<p>{msg}</p>}</form></div>}

export default function App(){const[ready,setReady]=useState(false);const[logged,setLogged]=useState(false);useEffect(()=>{void supabase.auth.getSession().then(({data})=>{setLogged(Boolean(data.session));setReady(true)});const{data}=supabase.auth.onAuthStateChange((_e,s)=>setLogged(Boolean(s)));return()=>data.subscription.unsubscribe()},[]);if(!ready)return null;return logged?<Shell/>:<Login/>}

function Dashboard(){const[counts,setCounts]=useState({imports:0,sales:0,unmapped:0,costed:0,missing:0,low:0,draftCounts:0});useEffect(()=>{void Promise.all([supabase.from('gpos_imports').select('*',{count:'exact',head:true}),supabase.from('sales_transactions').select('*',{count:'exact',head:true}),supabase.from('sales_items').select('*',{count:'exact',head:true}).eq('mapping_status','UNMAPPED'),supabase.from('sales_items').select('*',{count:'exact',head:true}).eq('costing_status','PROCESSED'),supabase.from('sales_items').select('*',{count:'exact',head:true}).in('costing_status',['MISSING_COST','ERROR']),supabase.from('inventory_summary').select('*',{count:'exact',head:true}).eq('is_low_stock',true),supabase.from('stock_counts').select('*',{count:'exact',head:true}).eq('status','DRAFT')]).then(([a,b,c,d,e,f,g])=>setCounts({imports:a.count??0,sales:b.count??0,unmapped:c.count??0,costed:d.count??0,missing:e.count??0,low:f.count??0,draftCounts:g.count??0}))},[]);return <><h1>แดชบอร์ด</h1><p className="lead">ภาพรวมระบบขาย GPOS สูตร ต้นทุน จัดซื้อ สต็อก และกำไรเชิงบริหารของ INFLOW Riverside Café</p><div className="cards"><Card t="ไฟล์ GPOS ที่นำเข้า" v={String(counts.imports)}/><Card t="ใบขาย" v={String(counts.sales)}/><Card t="รายการขายยังไม่จับคู่" v={String(counts.unmapped)}/><Card t="รายการที่คำนวณต้นทุนแล้ว" v={String(counts.costed)}/><Card t="ต้นทุนขาด/ผิดพลาด" v={String(counts.missing)}/><Card t="วัตถุดิบใกล้หมด" v={String(counts.low)}/><Card t="รอบตรวจนับที่เปิดอยู่" v={String(counts.draftCounts)}/></div></>}
function Card({t,v}:{t:string;v:string}){return <div className="card"><small>{t}</small><strong>{v}</strong></div>}
function ComingSoon({title}:{title:string}){return <><h1>{title}</h1><div className="panel">ส่วนนี้อยู่ในแผนการพัฒนารอบถัดไป</div></>}
function Settings(){return <><h1>ตั้งค่า</h1><div className="panel"><h2>สิทธิ์การใช้งาน</h2><p>OWNER และ MANAGER จัดการข้อมูลหลัก สูตร สต็อก การรับซื้อ การปิดรอบตรวจนับ การ Void ค่าใช้จ่าย และรายงานได้ ส่วน STAFF บันทึกงานประจำวันตามสิทธิ์ RLS ที่ฐานข้อมูลกำหนด</p></div></>}

function MasterData({title,table,fields}:{title:string;table:string;fields:string[]}){const[rows,setRows]=useState<Record<string,unknown>[]>([]);const[form,setForm]=useState<Record<string,string>>({});const[msg,setMsg]=useState('');const load=useCallback(async()=>{const{data,error}=await supabase.from(table).select('*').limit(50);setRows((data??[]) as Record<string,unknown>[]);if(error)setMsg(error.message)},[table]);useEffect(()=>{void load()},[load]);async function create(e:React.FormEvent){e.preventDefault();setMsg('');const payload=Object.fromEntries(fields.map(f=>[f,(f.includes('price')||f.includes('order'))?Number(form[f]||0):(form[f]||null)]));const{error}=await supabase.from(table).insert(payload);if(error){setMsg(error.message);return}setForm({});setMsg('บันทึกแล้ว');await load()}async function edit(row:Record<string,unknown>){const payload:Record<string,unknown>={};for(const f of fields){const next=window.prompt(`แก้ไข ${fieldLabel(f)}`,String(row[f]??''));if(next===null)return;payload[f]=(f.includes('price')||f.includes('order'))?Number(next):next||null}const{error}=await supabase.from(table).update(payload).eq('id',String(row.id));if(error)setMsg(error.message);else{setMsg('แก้ไขแล้ว');await load()}}async function deactivate(id:string){const{error}=await supabase.from(table).update({is_active:false}).eq('id',id);if(error)setMsg(error.message);else await load()}return <><h1>{title}</h1><div className="panel"><form className="crudform" onSubmit={e=>void create(e)}>{fields.map(f=><input key={f} placeholder={fieldLabel(f)} aria-label={fieldLabel(f)} value={form[f]??''} onChange={e=>setForm(x=>({...x,[f]:e.target.value}))} required={!['name_en','phone','email'].includes(f)}/>) }<button>เพิ่ม</button></form>{msg&&<p>{msg}</p>}<div className="tablewrap"><table><thead><tr>{fields.map(f=><th key={f}>{fieldLabel(f)}</th>)}<th>จัดการ</th></tr></thead><tbody>{rows.map((row,i)=><tr key={String(row.id??i)}>{fields.map(f=><td key={f}>{String(row[f]??'')}</td>)}<td><button className="smallbtn" onClick={()=>void edit(row)}>แก้ไข</button> {row.is_active!==undefined&&<button className="smallbtn danger" onClick={()=>void deactivate(String(row.id))}>ปิดใช้งาน</button>}</td></tr>)}</tbody></table></div></div></>}
