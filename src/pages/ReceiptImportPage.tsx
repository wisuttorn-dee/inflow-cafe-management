import {useCallback,useEffect,useMemo,useState} from 'react';
import {Link} from 'react-router-dom';
import {supabase} from '../lib/supabase';
import {uiError} from '../lib/ui';

type Supplier={id:string;supplier_name:string};
type Category={id:string;code:string;name_th:string;is_inventory_related:boolean};
type Ingredient={id:string;ingredient_code:string;name_th:string;name_en:string|null;base_unit_id:string};
type Unit={id:string;code:string;name_th:string;unit_type:string};
type LineType='INVENTORY'|'EXPENSE'|'REVIEW';
type Line={id:string;item_name:string;line_type:LineType;quantity:string;amount:string;ingredient_id:string;purchase_unit_id:string;base_quantity:string;expense_category_id:string;notes:string};

const MAX_RECEIPT_BYTES=5*1024*1024;
const ALLOWED_RECEIPTS=['application/pdf','image/jpeg','image/png','image/webp'];
const paymentOptions=[['CASH','เงินสด'],['PROMPTPAY','พร้อมเพย์'],['CARD','บัตร'],['TRANSFER','โอนเงิน'],['PLATFORM','ชำระผ่านแพลตฟอร์ม'],['OTHER','อื่น ๆ']] as const;
const newLine=():Line=>({id:crypto.randomUUID(),item_name:'',line_type:'REVIEW',quantity:'1',amount:'',ingredient_id:'',purchase_unit_id:'',base_quantity:'',expense_category_id:'',notes:''});

export function ReceiptImportPage(){
 const[suppliers,setSuppliers]=useState<Supplier[]>([]),[categories,setCategories]=useState<Category[]>([]),[ingredients,setIngredients]=useState<Ingredient[]>([]),[units,setUnits]=useState<Unit[]>([]);
 const[receiptDate,setReceiptDate]=useState(new Date().toISOString().slice(0,10)),[supplier,setSupplier]=useState(''),[payment,setPayment]=useState('CASH'),[reference,setReference]=useState(''),[notes,setNotes]=useState(''),[receipt,setReceipt]=useState<File|null>(null),[lines,setLines]=useState<Line[]>([newLine()]);
 const[msg,setMsg]=useState(''),[busy,setBusy]=useState(false),[ocrBusy,setOcrBusy]=useState(false),[ocrProgress,setOcrProgress]=useState(''),[ocrText,setOcrText]=useState('');

 const load=useCallback(async()=>{
   const[a,b,c,d]=await Promise.all([
    supabase.from('suppliers').select('id,supplier_name').eq('is_active',true).order('supplier_name'),
    supabase.from('expense_categories').select('id,code,name_th,is_inventory_related').eq('is_active',true).eq('is_inventory_related',false).order('code'),
    supabase.from('ingredients').select('id,ingredient_code,name_th,name_en,base_unit_id').eq('is_active',true).order('ingredient_code'),
    supabase.from('units').select('id,code,name_th,unit_type').eq('is_active',true).order('code')
   ]);
   if(a.error||b.error||c.error||d.error){setMsg(uiError('โหลดข้อมูลสำหรับนำเข้าใบเสร็จ'));return}
   setSuppliers((a.data??[]) as Supplier[]);setCategories((b.data??[]) as Category[]);setIngredients((c.data??[]) as Ingredient[]);setUnits((d.data??[]) as Unit[]);
 },[]);
 useEffect(()=>{void load()},[load]);

 const total=useMemo(()=>lines.reduce((s,l)=>s+(Number(l.amount)||0),0),[lines]);
 const inventoryTotal=useMemo(()=>lines.filter(l=>l.line_type==='INVENTORY').reduce((s,l)=>s+(Number(l.amount)||0),0),[lines]);
 const expenseTotal=useMemo(()=>lines.filter(l=>l.line_type==='EXPENSE').reduce((s,l)=>s+(Number(l.amount)||0),0),[lines]);
 const reviewCount=lines.filter(l=>l.line_type==='REVIEW').length;

 function updateLine(id:string,patch:Partial<Line>){setLines(xs=>xs.map(x=>x.id===id?{...x,...patch}:x))}
 function removeLine(id:string){setLines(xs=>xs.length===1?[newLine()]:xs.filter(x=>x.id!==id))}

 function normalizeText(value:string){return value.toLowerCase().replace(/[^a-z0-9ก-๙]+/g,' ').replace(/\s+/g,' ').trim()}
 function guessExpenseCategory(name:string){
   const n=normalizeText(name);
   const keywordMap:[string,string[]][]=[
     ['CLEANING',['น้ำยาล้าง','ล้างจาน','ทำความสะอาด','สบู่','ทิชชู่','toilet','clean','detergent']],
     ['EQUIPMENT',['เหยือก','ขวดซอส','อุปกรณ์','เครื่องมือ','pitcher','equipment','bottle']],
     ['MARKETING',['ป้าย','โฆษณา','สติ๊กเกอร์','sticker','advertising','marketing']],
     ['TRANSPORTATION',['ขนส่ง','ค่าส่ง','delivery','transport']],
     ['STAFF',['พนักงาน','staff']],
     ['UTILITIES',['ค่าไฟ','ค่าน้ำ','electric','water bill']]
   ];
   for(const [code,words] of keywordMap){if(words.some(w=>n.includes(normalizeText(w))))return categories.find(c=>c.code===code)?.id??''}
   return '';
 }
 function guessIngredient(name:string){
   const n=normalizeText(name);if(n.length<2)return '';
   const ranked=ingredients.map(i=>{
     const a=normalizeText(i.name_th),b=normalizeText(i.name_en??'');
     let score=0;
     if(a&&n.includes(a))score=Math.max(score,a.length+20);
     if(b&&n.includes(b))score=Math.max(score,b.length+20);
     for(const token of a.split(' ')){if(token.length>=3&&n.includes(token))score+=token.length}
     for(const token of b.split(' ')){if(token.length>=4&&n.includes(token))score+=token.length}
     return {id:i.id,score};
   }).sort((x,y)=>y.score-x.score);
   return ranked[0]?.score>=5?ranked[0].id:'';
 }
 function parseReceiptText(text:string){
   const parsed:Line[]=[];
   for(const raw of text.split(/\r?\n/)){
     const line=raw.replace(/\s+/g,' ').trim();
     if(!line||line.length<3)continue;
     if(/^(total|subtotal|vat|change|cash|ยอดรวม|รวมทั้งสิ้น|เงินทอน|ภาษี|เลขที่|วันที่|เวลา)/i.test(line))continue;
     const matches=[...line.matchAll(/(?:^|\s)(-?\d{1,6}(?:[,.]\d{2})?)(?=\s|$)/g)];
     if(matches.length===0)continue;
     const last=matches[matches.length-1];
     const amount=Number(last[1].replace(',','.'));
     if(!Number.isFinite(amount)||amount<=0)continue;
     const itemName=line.slice(0,last.index).replace(/^\d+\s*[xX*]\s*/,'').trim();
     if(!itemName||itemName.length<2)continue;
     const ingredientId=guessIngredient(itemName);
     const expenseCategoryId=ingredientId?'':guessExpenseCategory(itemName);
     parsed.push({
       ...newLine(),item_name:itemName,amount:String(amount),
       line_type:ingredientId?'INVENTORY':expenseCategoryId?'EXPENSE':'REVIEW',
       ingredient_id:ingredientId,expense_category_id:expenseCategoryId
     });
   }
   return parsed;
 }
 async function loadTesseract(){
   const w=window as unknown as {Tesseract?:{recognize:(file:File,lang:string,options?:{logger?:(m:{status?:string;progress?:number})=>void})=>Promise<{data:{text:string}}>}};
   if(w.Tesseract)return w.Tesseract;
   await new Promise<void>((resolve,reject)=>{
     const existing=document.querySelector('script[data-inflow-tesseract]') as HTMLScriptElement|null;
     if(existing){existing.addEventListener('load',()=>resolve(),{once:true});existing.addEventListener('error',()=>reject(new Error('โหลด OCR ไม่สำเร็จ')),{once:true});return}
     const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';s.async=true;s.dataset.inflowTesseract='1';s.onload=()=>resolve();s.onerror=()=>reject(new Error('โหลด OCR ไม่สำเร็จ'));document.head.appendChild(s);
   });
   const ready=(window as unknown as {Tesseract?:{recognize:(file:File,lang:string,options?:{logger?:(m:{status?:string;progress?:number})=>void})=>Promise<{data:{text:string}}>}}).Tesseract;
   if(!ready)throw new Error('OCR ยังไม่พร้อมใช้งาน');return ready;
 }
 async function readReceiptAutomatically(){
   if(!receipt){setMsg('กรุณาเลือกไฟล์ใบเสร็จก่อน');return}
   if(!receipt.type.startsWith('image/')){setMsg('อ่านข้อความอัตโนมัติรองรับ JPG, PNG และ WebP ก่อน สำหรับ PDF กรุณาใช้ไฟล์ภาพ');return}
   setMsg('');setOcrBusy(true);setOcrProgress('กำลังเตรียม OCR...');
   try{
     const t=await loadTesseract();
     const result=await t.recognize(receipt,'tha+eng',{logger:m=>{if(typeof m.progress==='number')setOcrProgress(`${m.status??'กำลังอ่าน'} ${Math.round(m.progress*100)}%`)}});
     const text=result.data.text??'';setOcrText(text);
     const parsed=parseReceiptText(text);
     if(parsed.length===0){setMsg('อ่านข้อความได้ แต่ยังแยกรายการสินค้าอัตโนมัติไม่ได้ กรุณาตรวจข้อความ OCR ด้านล่าง');return}
     setLines(parsed);setMsg(`อ่านใบเสร็จแล้ว ${parsed.length} รายการ กรุณาตรวจเฉพาะรายการที่ขึ้น “รอตรวจสอบ” ก่อนยืนยัน`);
   }catch(error){setMsg(error instanceof Error?error.message:'อ่านข้อความใบเสร็จไม่สำเร็จ')}finally{setOcrBusy(false);setOcrProgress('')}
 }

 async function uploadReceipt(file:File){
   if(file.size>MAX_RECEIPT_BYTES)throw new Error('ไฟล์ใบเสร็จต้องไม่เกิน 5 MB');
   if(!ALLOWED_RECEIPTS.includes(file.type))throw new Error('รองรับเฉพาะ PDF, JPG, PNG และ WebP');
   const{data:{user}}=await supabase.auth.getUser();if(!user)throw new Error('กรุณาเข้าสู่ระบบใหม่');
   const ext=(file.name.split('.').pop()||'bin').toLowerCase();
   const path=`${user.id}/mixed-${Date.now()}-${crypto.randomUUID()}.${ext}`;
   const{error}=await supabase.storage.from('expense-receipts').upload(path,file,{contentType:file.type,upsert:false});
   if(error)throw new Error(uiError('อัปโหลดใบเสร็จ'));return path;
 }

 function validate(confirm:boolean){
   if(!receipt)return 'กรุณาเลือกไฟล์ใบเสร็จ';
   if(lines.length===0)return 'กรุณาเพิ่มอย่างน้อย 1 รายการ';
   for(const l of lines){
     if(!l.item_name.trim()||!(Number(l.amount)>0)||!(Number(l.quantity)>0))return 'กรุณากรอกชื่อรายการ จำนวน และยอดเงินให้ครบ';
     if(confirm&&l.line_type==='REVIEW')return 'ยังมีรายการที่รอตรวจสอบ กรุณาเลือกประเภทให้ครบก่อนยืนยัน';
     if(l.line_type==='INVENTORY'&&(!l.ingredient_id||!l.purchase_unit_id))return 'รายการวัตถุดิบต้องเลือกวัตถุดิบและหน่วยซื้อ';
     if(l.line_type==='EXPENSE'&&!l.expense_category_id)return 'รายการค่าใช้จ่ายต้องเลือกหมวดค่าใช้จ่าย';
   }
   return '';
 }

 async function save(confirm:boolean){
   setMsg('');const invalid=validate(confirm);if(invalid){setMsg(invalid);return}
   setBusy(true);let receiptPath:string|null=null;let importId:string|null=null;
   try{
     const{data:{user}}=await supabase.auth.getUser();if(!user)throw new Error('กรุณาเข้าสู่ระบบใหม่');
     receiptPath=await uploadReceipt(receipt!);
     const{data:header,error:hErr}=await supabase.from('receipt_imports').insert({
       receipt_date:receiptDate,supplier_id:supplier||null,payment_method:payment||null,reference_no:reference.trim()||null,
       receipt_url:receiptPath,notes:notes.trim()||null,created_by:user.id,status:'DRAFT'
     }).select('id').single();
     if(hErr||!header)throw new Error(uiError('สร้างรายการนำเข้าใบเสร็จ'));
     importId=String(header.id);
     const payload=lines.map((l,index)=>({
       receipt_import_id:importId,item_name:l.item_name.trim(),line_type:l.line_type,quantity:Number(l.quantity),amount:Number(l.amount),
       ingredient_id:l.line_type==='INVENTORY'?l.ingredient_id:null,purchase_unit_id:l.line_type==='INVENTORY'?l.purchase_unit_id:null,
       base_quantity:l.line_type==='INVENTORY'&&l.base_quantity?Number(l.base_quantity):null,
       expense_category_id:l.line_type==='EXPENSE'?l.expense_category_id:null,notes:l.notes.trim()||null,display_order:index+1
     }));
     const{error:lErr}=await supabase.from('receipt_import_lines').insert(payload);if(lErr)throw new Error(uiError('บันทึกรายการในใบเสร็จ'));
     if(confirm){
       const{error:cErr}=await supabase.rpc('confirm_receipt_import',{p_receipt_import_id:importId});if(cErr)throw new Error(uiError('ยืนยันและแยกบันทึกใบเสร็จ'));
       setMsg('ยืนยันเรียบร้อย: วัตถุดิบถูกส่งไปเป็น Purchase DRAFT และค่าใช้จ่ายถูกบันทึกแล้ว');
     }else setMsg('บันทึกร่างใบเสร็จเรียบร้อยแล้ว');
     setReceipt(null);setReference('');setNotes('');setSupplier('');setLines([newLine()]);
   }catch(error){
     if(importId)await supabase.from('receipt_imports').delete().eq('id',importId);
     if(receiptPath)await supabase.storage.from('expense-receipts').remove([receiptPath]);
     setMsg(error instanceof Error?error.message:uiError('นำเข้าใบเสร็จ'));
   }finally{setBusy(false)}
 }

 return <><div className="pagehead"><div><h1>นำเข้าใบเสร็จรวม</h1><p className="lead">ใบเสร็จ 1 ใบสามารถมีทั้งวัตถุดิบและค่าใช้จ่าย ระบบจะแยกไปยังจัดซื้อและค่าใช้จ่ายเมื่อยืนยัน</p></div><Link className="secondary" to="/expenses">กลับค่าใช้จ่าย</Link></div>
 <div className="cards compact"><div className="card"><small>ยอดรวม</small><strong>฿{total.toFixed(2)}</strong></div><div className="card"><small>วัตถุดิบ/สต็อก</small><strong>฿{inventoryTotal.toFixed(2)}</strong></div><div className="card"><small>ค่าใช้จ่าย</small><strong>฿{expenseTotal.toFixed(2)}</strong></div><div className="card"><small>รอตรวจสอบ</small><strong>{reviewCount}</strong></div></div>
 <div className="panel"><h2>ข้อมูลใบเสร็จ</h2><div className="crudform"><input type="date" value={receiptDate} onChange={e=>setReceiptDate(e.target.value)}/><select value={supplier} onChange={e=>setSupplier(e.target.value)}><option value="">ผู้ขาย (ถ้ามี)</option>{suppliers.map(s=><option key={s.id} value={s.id}>{s.supplier_name}</option>)}</select><select value={payment} onChange={e=>setPayment(e.target.value)}>{paymentOptions.map(([c,l])=><option key={c} value={c}>{l}</option>)}</select><input placeholder="เลขอ้างอิง/เลขที่ใบเสร็จ" value={reference} onChange={e=>setReference(e.target.value)}/><input placeholder="หมายเหตุ" value={notes} onChange={e=>setNotes(e.target.value)}/><label className="filepick">ไฟล์ใบเสร็จ<input type="file" accept="application/pdf,image/jpeg,image/png,image/webp" onChange={e=>{setReceipt(e.target.files?.[0]??null);setOcrText('')}}/></label><button type="button" className="secondary" disabled={!receipt||ocrBusy} onClick={()=>void readReceiptAutomatically()}>{ocrBusy?'กำลังอ่าน...':'อ่านข้อความอัตโนมัติ'}</button></div>{receipt&&<p className="muted">ไฟล์: {receipt.name}</p>}{ocrProgress&&<p className="muted">{ocrProgress}</p>}{ocrText&&<details><summary>ดูข้อความที่ OCR อ่านได้</summary><pre style={{whiteSpace:'pre-wrap'}}>{ocrText}</pre></details>}</div>
 <div className="panel"><div className="pagehead"><div><h2>รายการในใบเสร็จ</h2><p className="muted">เลือกประเภทของแต่ละบรรทัดก่อนยืนยัน รายการวัตถุดิบจะยังเป็น Purchase DRAFT จนกว่าจะตรวจหน่วย/ขนาดบรรจุและรับเข้าสต็อก</p></div><button onClick={()=>setLines(xs=>[...xs,newLine()])}>+ เพิ่มรายการ</button></div>
 <div className="tablewrap"><table><thead><tr><th>รายการ</th><th>ประเภท</th><th>จำนวน</th><th>ยอดเงิน</th><th>การจับคู่</th><th>หน่วย/หมวด</th><th>ฐานรวม (ถ้าทราบ)</th><th>หมายเหตุ</th><th></th></tr></thead><tbody>
 {lines.map(l=><tr key={l.id}><td><input value={l.item_name} onChange={e=>updateLine(l.id,{item_name:e.target.value})} placeholder="ชื่อสินค้า"/></td><td><select value={l.line_type} onChange={e=>updateLine(l.id,{line_type:e.target.value as LineType,ingredient_id:'',purchase_unit_id:'',expense_category_id:''})}><option value="REVIEW">รอตรวจสอบ</option><option value="INVENTORY">วัตถุดิบ/สต็อก</option><option value="EXPENSE">ค่าใช้จ่าย</option></select></td><td><input type="number" min="0.0001" step="0.0001" value={l.quantity} onChange={e=>updateLine(l.id,{quantity:e.target.value})}/></td><td><input type="number" min="0.01" step="0.01" value={l.amount} onChange={e=>updateLine(l.id,{amount:e.target.value})} placeholder="บาท"/></td><td>{l.line_type==='INVENTORY'?<select value={l.ingredient_id} onChange={e=>updateLine(l.id,{ingredient_id:e.target.value})}><option value="">เลือกวัตถุดิบ</option>{ingredients.map(i=><option key={i.id} value={i.id}>{i.ingredient_code} · {i.name_th}</option>)}</select>:l.line_type==='EXPENSE'?<select value={l.expense_category_id} onChange={e=>updateLine(l.id,{expense_category_id:e.target.value})}><option value="">เลือกหมวด</option>{categories.map(c=><option key={c.id} value={c.id}>{c.name_th}</option>)}</select>:'—'}</td><td>{l.line_type==='INVENTORY'?<select value={l.purchase_unit_id} onChange={e=>updateLine(l.id,{purchase_unit_id:e.target.value})}><option value="">เลือกหน่วยซื้อ</option>{units.map(u=><option key={u.id} value={u.id}>{u.name_th} ({u.code})</option>)}</select>:'—'}</td><td>{l.line_type==='INVENTORY'?<input type="number" min="0" step="0.0001" value={l.base_quantity} onChange={e=>updateLine(l.id,{base_quantity:e.target.value})} placeholder="เช่น 2000 ml"/>:'—'}</td><td><input value={l.notes} onChange={e=>updateLine(l.id,{notes:e.target.value})}/></td><td><button className="smallbtn danger" onClick={()=>removeLine(l.id)}>ลบ</button></td></tr>)}
 </tbody></table></div>
 <div className="toolbar"><button disabled={busy||reviewCount>0} onClick={()=>void save(true)}>{busy?'กำลังบันทึก...':'ยืนยันและแยกบันทึก'}</button></div>{msg&&<div className="warn">{msg}</div>}</div></>;
}
