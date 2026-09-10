insert into public.units(code,name_th,name_en,unit_type,decimal_places,is_active) values
('KG','กิโลกรัม','Kilogram','WEIGHT',3,true),
('L','ลิตร','Liter','VOLUME',3,true),
('BOTTLE','ขวด','Bottle','PURCHASE_UNIT',0,true),
('CAN','กระป๋อง','Can','PURCHASE_UNIT',0,true),
('BAG','ถุง','Bag','PURCHASE_UNIT',0,true),
('PACK','แพ็ก','Pack','PURCHASE_UNIT',0,true),
('BOX','กล่อง','Box','PURCHASE_UNIT',0,true),
('BOTTLE_1L','ขวด 1 ลิตร','1 Liter Bottle','PURCHASE_UNIT',0,true),
('BOTTLE_2L','ขวด 2 ลิตร','2 Liter Bottle','PURCHASE_UNIT',0,true)
on conflict (code) do update set
  name_th=excluded.name_th,
  name_en=excluded.name_en,
  unit_type=excluded.unit_type,
  decimal_places=excluded.decimal_places,
  is_active=true;

with pairs(from_code,to_code,factor) as (
  values
    ('KG','G',1000::numeric),
    ('L','ML',1000::numeric),
    ('BOTTLE_1L','ML',1000::numeric),
    ('BOTTLE_2L','ML',2000::numeric)
), resolved as (
  select f.id from_id,t.id to_id,p.factor
  from pairs p
  join public.units f on f.code=p.from_code
  join public.units t on t.code=p.to_code
)
insert into public.unit_conversions(from_unit_id,to_unit_id,conversion_factor,ingredient_id,is_active)
select r.from_id,r.to_id,r.factor,null,true
from resolved r
where not exists (
  select 1 from public.unit_conversions u
  where u.from_unit_id=r.from_id
    and u.to_unit_id=r.to_id
    and u.ingredient_id is null
);

update public.recipes r
set notes=trim(both from concat_ws(E'\n',
  nullif(r.notes,''),
  'อ้างอิงไฟล์สูตรเครื่องดื่มที่อัปโหลด 10 ก.ย. 2026; เมนูที่มีนมผสมใช้สูตรหวานปกติเป็นค่าเริ่มต้น โดยแปลงนมผสมเป็นนมข้นหวาน 75% + นมข้นจืด 25% เพื่อให้ตัดสต็อกวัตถุดิบจริงได้'
))
where r.status='ACTIVE'
  and exists (
    select 1 from public.menu_items m
    where m.id=r.menu_item_id and m.is_active=true
  )
  and coalesce(r.notes,'') not like '%อ้างอิงไฟล์สูตรเครื่องดื่มที่อัปโหลด 10 ก.ย. 2026%';
