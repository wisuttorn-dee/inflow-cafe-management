alter table public.ingredients add column if not exists preferred_brand text null;
alter table public.ingredients add column if not exists purchase_specification text null;
alter table public.ingredients add column if not exists purchase_notes text null;

create table if not exists public.purchase_catalog (
 id uuid primary key default gen_random_uuid(),
 category text not null,
 item_name text not null unique,
 preferred_brand text null,
 usage_context text null,
 source_context text null,
 notes text null,
 item_type text not null default 'INGREDIENT' check (item_type in ('INGREDIENT','PACKAGING','EQUIPMENT')),
 is_active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.purchase_catalog enable row level security;
revoke all on public.purchase_catalog from anon,public;
grant select,insert,update on public.purchase_catalog to authenticated;
drop policy if exists purchase_catalog_read on public.purchase_catalog;
create policy purchase_catalog_read on public.purchase_catalog for select to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER','STAFF'));
drop policy if exists purchase_catalog_manage on public.purchase_catalog;
create policy purchase_catalog_manage on public.purchase_catalog for all to authenticated using ((select private.current_user_role()) in ('OWNER','MANAGER')) with check ((select private.current_user_role()) in ('OWNER','MANAGER'));

insert into public.purchase_catalog(category,item_name,preferred_brand,usage_context,source_context,notes,item_type) values
('นมและครีม','นมสดพาสเจอร์ไรส์','Meiji','กาแฟนม, Matcha, เมนูนม, เมนูปั่น, Neutral Cloud Base','รูป + Excel',null,'INGREDIENT'),
('นมและครีม','นมข้นหวาน','Teapot','ใช้เตรียมนมผสม','รูป + Excel','สูตรนมผสมล่าสุด 2:1 = นมข้นหวาน 100 ml + นมข้นจืด 50 ml','INGREDIENT'),
('นมและครีม','นมข้นจืด','Teapot','กาแฟนม, ชานม, Matcha Latte, เมนูนม และนมผสม','รูป + Excel','สูตรนมผสมล่าสุด 2:1','INGREDIENT'),
('นมและครีม','ครีมเทียมชนิดผง','B1','Espresso Cold, Cappuccino Cold, Mocha Cold, ชานม, Taro Milk','รูป + Excel',null,'INGREDIENT'),
('นมและครีม','ผงครีมชีส','Dreamy','ครีมชีสสำหรับเมนูปั่นและ topping','รูป + Excel',null,'INGREDIENT'),
('นมและครีม','ผงวิปปิ้งครีมสูตรจืด','Dreamy','Neutral Cloud Base และซอฟต์ครีม','รูป + Excel',null,'INGREDIENT'),
('กาแฟ ชา และผง','เมล็ดกาแฟคั่ว','Boncafé','กาแฟทุกเมนู','รูป + Excel','ระดับการคั่วควรยืนยันอีกครั้ง เพราะสูตรเดิมมีการแยกกาแฟบางเมนูตามการบด/การสกัด','INGREDIENT'),
('กาแฟ ชา และผง','ใบชาไทย','Bluemocha','Thai Milk Tea, Lemon Tea, Coconut Thai Tea Cloud','Excel',null,'INGREDIENT'),
('กาแฟ ชา และผง','ใบชาเขียว','Bluemocha','Green Milk Tea และฐานชาเขียว/ชาจัสมินบางเมนู','รูป + Excel','ในรูปเขียน Green Tea ตรามือ และระบุถุงเหลือง','INGREDIENT'),
('กาแฟ ชา และผง','ใบชาสำหรับชานมไต้หวัน','Bluemocha','Taiwanese Milk Tea','Excel','ชนิด/ยี่ห้อยังไม่ได้ระบุในไฟล์','INGREDIENT'),
('กาแฟ ชา และผง','ผงมัทฉะ','Bluemocha','Pure Matcha, Matcha Latte, Strawberry Matcha, Coconut Matcha, Orange Matcha, Coconut Matcha Cloud','Excel','ควรระบุเกรดและยี่ห้อหลังทดสอบสูตร','INGREDIENT'),
('กาแฟ ชา และผง','ผงโกโก้',null,'Cocoa, Mocha, Coconut Cocoa Cloud','รูป + Excel',null,'INGREDIENT'),
('กาแฟ ชา และผง','ผงเผือก',null,'Taro Milk','รูป + Excel','ในรูปเขียนว่าใช้อันเดิม แต่ไม่ได้ระบุยี่ห้อ','INGREDIENT'),
('กาแฟ ชา และผง','ผงแคนตาลูป',null,'สำรองสำหรับเมนูนมแคนตาลูป/สูตรเดิม','รูป','เมนูปัจจุบันใน Excel ไม่มี Cantaloupe Milk แต่รายการซื้อในรูปยังระบุไว้','INGREDIENT'),
('กาแฟ ชา และผง','ผงชาพีช',null,'Peach Tea','Excel',null,'INGREDIENT'),
('กาแฟ ชา และผง','ผงมะนาว',null,'Lemon Tea','รูป + Excel','ชื่อยี่ห้อในลายมืออ่านคล้าย Knorr แต่ควรยืนยันจากบรรจุภัณฑ์จริง','INGREDIENT'),
('กาแฟ ชา และผง','ผงวุ้นหรือผงเจลลี่',null,'Grape Jelly','รูป + Excel','ไม่แน่ใจว่าเป็นผงวุ้นทั่วไปหรือ Aiyu Jelly Powder ควรตรวจชื่อสินค้าจริง','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','น้ำเชื่อมสำเร็จรูปหรือ Simple Syrup',null,'กาแฟ, Matcha, ชา, Mocktail, Coconut Cloud','รูป + Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปวานิลลา','MONIN','รายการซื้อจากรูป และใช้เป็น flavouring สำรอง','รูป',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปสตรอว์เบอร์รี','Nature Taste','Pink River, Sunset by the River, Strawberry Cheesecake Smoothie','รูป + Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','สตรอว์เบอร์รีพิวเร่','Nature Taste','Strawberry Matcha, Strawberry Milk, Pink River','Excel','บางเมนูใช้ puree ขณะที่บางเมนูระบุ syrup จึงควรมีทั้งสองชนิดหรือเลือกผลิตภัณฑ์เดียวหลังทดลอง','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปลิ้นจี่',null,'Pink River, Lychee Breeze','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','พิวเร่เสาวรส','Nature Taste','Golden Flow, Sunset by the River','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปแอปเปิลเขียว',null,'Green Riverside','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปหรือพิวเร่พีช',null,'Peach Garden','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปน้ำผึ้ง',null,'Yuzu Honey Fizz','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','น้ำผึ้งแท้',null,'Honey Milk','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปยูซุหรือยูซุเข้มข้น','MONIN','River Flow, Yuzu Honey Fizz','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปคาราเมล','Long Beach','Caramel Milk','รูป + Excel','ลายมืออ่านได้ว่า Long Beach แต่ควรยืนยันรุ่น/ชนิด','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปมะพร้าว',null,'Coconut Coffee','Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปองุ่นสีม่วง','Nature Taste','Grape Tea และ Grape Tea Smoothie','รูป + Excel',null,'INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปองุ่นหรือไซรัปชบาสำหรับเจลลี่องุ่น',null,'Grape Jelly','รูป + Excel','ชื่อผลิตภัณฑ์ในต้นฉบับสูตรระบุ ไซรัปองุ่น/ชบา จึงควรยืนยันว่าต้องการรสองุ่นหรือชบา','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปกลิ่นองุ่นขาว',null,'รายการซื้อจากรูป','รูป','ชื่อยี่ห้อไม่ชัด ควรตรวจขวดเดิมก่อนซื้อ','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','ไซรัปบลูคูราเซาหรือไซรัปสีฟ้า','Nature Taste','รายการซื้อจากรูป','รูป','ลายมืออ่านได้เพียงคำว่า บลู ติ่งฟง จึงยังไม่ยืนยันว่าเป็น Blue Curaçao','INGREDIENT'),
('ไซรัป พิวเร่ และสารให้ความหวาน','น้ำหวานสีแดง','Hale''s Blue Boy','รายการซื้อจากรูป/สูตรนมชมพูเดิม','รูป',null,'INGREDIENT'),
('น้ำผลไม้และของเหลว','น้ำส้ม 100% รสแมนดาริน','Malee','Orange Coffee, Orange Matcha, Golden Flow, Sunset by the River','รูป + Excel','ลายมือระบุ Malee Mandarin','INGREDIENT'),
('น้ำผลไม้และของเหลว','น้ำมะพร้าว',null,'Coconut Coffee, Coconut Matcha, Coconut Cloud Series','Excel',null,'INGREDIENT'),
('น้ำผลไม้และของเหลว','กะทิหรือนมมะพร้าว',null,'Coconut Coffee และ Coconut Matcha','Excel','สูตร Coconut Cloud ล่าสุดไม่ใช้ Coconut milk แต่สองเมนูนี้ใน Excel ยังใช้','INGREDIENT'),
('น้ำผลไม้และของเหลว','น้ำมะนาวสดหรือมะนาวสด',null,'Mocktail และเมนูมะนาว','รูป + Excel','ข้อความลายมือช่วงท้ายอ่านไม่ชัด แต่สูตร Excel ต้องใช้ Lemon/Lime Juice','INGREDIENT'),
('น้ำผลไม้และของเหลว','โซดา',null,'Mocktail และ Cheesecake Smoothie','Excel',null,'INGREDIENT'),
('น้ำผลไม้และของเหลว','น้ำดื่มสำหรับชงเครื่องดื่ม',null,'กาแฟ, ชา, Matcha และการเตรียมฐาน','Excel',null,'INGREDIENT'),
('น้ำผลไม้และของเหลว','น้ำแข็งสำหรับเครื่องดื่ม',null,'เครื่องดื่มเย็นทุกหมวด','Excel',null,'INGREDIENT'),
('ท็อปปิงและอื่น ๆ','คุกกี้ช็อกโกแลตแซนด์วิชหรือคุกกี้สำหรับตกแต่ง',null,'Blueberry/Strawberry Cheesecake Smoothie','Excel','สูตรระบุเพียง คุกกี้ จึงควรเลือกรุ่นที่ใช้จริงแล้วล็อกยี่ห้อ','INGREDIENT'),
('บรรจุภัณฑ์และอุปกรณ์','แก้วร้อน',null,'เสิร์ฟกาแฟร้อน','รูป','ขนาดที่เขียนในรูปอ่านไม่ชัด จึงไม่ระบุขนาด','PACKAGING'),
('บรรจุภัณฑ์และอุปกรณ์','ฝาแก้ว',null,'ใช้คู่กับแก้วเครื่องดื่ม','รูป','ควรเลือกขนาดให้ตรงกับแก้วที่ร้านใช้','PACKAGING'),
('บรรจุภัณฑ์และอุปกรณ์','ตัวกรองหรือกระชอนกรองชา',null,'เตรียมชาและฐานชา','รูป','ลายมือเขียน ตัวกรอง ไม่ได้ระบุชนิด','EQUIPMENT'),
('บรรจุภัณฑ์และอุปกรณ์','เครื่องปั่นเครื่องดื่ม',null,'เมนูปั่น','รูป',null,'EQUIPMENT')
on conflict(item_name) do update set category=excluded.category,preferred_brand=excluded.preferred_brand,usage_context=excluded.usage_context,source_context=excluded.source_context,notes=excluded.notes,item_type=excluded.item_type,is_active=true,updated_at=now();

update public.ingredients set preferred_brand='Meiji',purchase_specification='นมสดพาสเจอร์ไรส์' where ingredient_code in ('BUY-001','FORMULA-032','FORMULA-033');
update public.ingredients set preferred_brand='Teapot',purchase_specification='นมข้นหวาน' where ingredient_code='FORMULA-031';
update public.ingredients set preferred_brand='Teapot',purchase_specification='นมข้นจืด' where ingredient_code='FORMULA-030';
update public.ingredients set preferred_brand='B1',purchase_specification='ครีมเทียมชนิดผง' where ingredient_code in ('BUY-004','FORMULA-024');
update public.ingredients set preferred_brand='Dreamy',purchase_specification='ผงครีมชีส' where ingredient_code='BUY-005';
update public.ingredients set preferred_brand='Dreamy',purchase_specification='ผงวิปปิ้งครีมสูตรจืด' where ingredient_code='BUY-006';
update public.ingredients set preferred_brand='Boncafé',purchase_specification='เมล็ดกาแฟคั่ว' where ingredient_code='BUY-007';
update public.ingredients set preferred_brand='Bluemocha',purchase_specification='ใบชาไทย' where ingredient_code='BUY-008';
update public.ingredients set preferred_brand='Bluemocha',purchase_specification='ใบชาเขียว' where ingredient_code='BUY-009';
update public.ingredients set preferred_brand='Bluemocha',purchase_specification='ใบชาสำหรับชานมไต้หวัน' where ingredient_code='BUY-010';
update public.ingredients set preferred_brand='Bluemocha',purchase_specification='ผงมัทฉะ' where ingredient_code in ('BUY-011','FORMULA-009','FORMULA-010');
update public.ingredients set preferred_brand='Nature Taste',purchase_specification='Strawberry syrup' where ingredient_code in ('BUY-020','FORMULA-019');
update public.ingredients set preferred_brand='Nature Taste',purchase_specification='Strawberry puree' where ingredient_code in ('BUY-021','FORMULA-017','FORMULA-018');
update public.ingredients set preferred_brand='Nature Taste',purchase_specification='Passion fruit puree' where ingredient_code in ('BUY-023','FORMULA-013');
update public.ingredients set preferred_brand='MONIN',purchase_specification='Yuzu syrup/concentrate' where ingredient_code in ('BUY-028','FORMULA-020');
update public.ingredients set preferred_brand='Long Beach',purchase_specification='Caramel syrup' where ingredient_code in ('BUY-029','FORMULA-002');
update public.ingredients set preferred_brand='Nature Taste',purchase_specification='Purple grape syrup' where ingredient_code in ('BUY-031','FORMULA-005');
update public.ingredients set preferred_brand='Nature Taste',purchase_specification='Blue syrup / Blue Curaçao' where ingredient_code='BUY-034';
update public.ingredients set preferred_brand='Hale''s Blue Boy',purchase_specification='น้ำหวานสีแดง' where ingredient_code='BUY-035';
update public.ingredients set preferred_brand='Malee',purchase_specification='100% Mandarin Orange Juice' where ingredient_code in ('BUY-036','FORMULA-012','FORMULA-035','FORMULA-036');
