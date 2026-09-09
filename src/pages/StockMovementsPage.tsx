import {useEffect,useState} from 'react';
import {supabase} from '../lib/supabase';

type Move={id:string;ingredient_id:string;movement_type:string;quantity_base_unit:number;unit_cost:number|null;total_cost:number|null;occurred_at:string;reference_type:string|null;notes:string|null};type Ing={id:string;ingredient_code:string;name_th:string};

const movementLabels:Record<string,string>={
 PURCHASE:'รับเข้าจากการจัดซื้อ',
 WASTE:'ของเสีย / สูญเสีย',
 SALE_USAGE:'ตัดสต็อกจากการขาย',
 STOCK_COUNT_ADJUSTMENT:'ปรับยอดจากการตรวจนับ',
 OPENING_STOCK:'ยอดยกมา',
 ADJUSTMENT:'ปรับยอด',
 TRANSFER:'โอนย้าย',
};
const referenceLabels:Record<string,string>={PURCHASE:'การจัดซื้อ',SALE:'การขาย',WASTE:'ของเสีย',STOCK_COUNT:'ตรวจนับสต็อก',OPENING_STOCK:'ยอดยกมา'};

export function StockMovementsPage(){const[rows,setRows]=useState<Move[]>([]),[ingredients,setIngredients]=useState<Ing[]>([]);useEffect(()=>{void Promise.all([supabase.from('inventory_movements').select('*').order('occurred_at',{ascending:false}).limit(200),supabase.from('ingredients').select('id,ingredient_code,name_th')]).then(([a,b])=>{setRows((a.data??[]) as Move[]);setIngredients((b.data??[]) as Ing[])})},[]);const ing=(id:string)=>{const x=ingredients.find(v=>v.id===id);return x?`${x.ingredient_code} · ${x.name_th}`:id};return <><h1>ความเคลื่อนไหวสต็อก</h1><p className="lead">ประวัติการเพิ่มและลดสต็อกทุกครั้ง โดยรายการนี้เป็นหลักฐานอ้างอิงของยอดสต็อกในระบบ</p><div className="panel"><div className="tablewrap"><table><thead><tr><th>วัน-เวลา</th><th>วัตถุดิบ</th><th>ประเภท</th><th>จำนวน</th><th>ต้นทุนต่อหน่วย</th><th>ต้นทุนรวม</th><th>รายการอ้างอิง</th><th>หมายเหตุ</th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td>{new Date(r.occurred_at).toLocaleString('th-TH')}</td><td>{ing(r.ingredient_id)}</td><td>{movementLabels[r.movement_type]??r.movement_type}</td><td>{Number(r.quantity_base_unit).toFixed(4)}</td><td>{r.unit_cost==null?'-':`฿${Number(r.unit_cost).toFixed(4)}`}</td><td>{r.total_cost==null?'-':`฿${Number(r.total_cost).toFixed(2)}`}</td><td>{r.reference_type?(referenceLabels[r.reference_type]??r.reference_type):'-'}</td><td>{r.notes??'-'}</td></tr>)}</tbody></table></div></div></>}
