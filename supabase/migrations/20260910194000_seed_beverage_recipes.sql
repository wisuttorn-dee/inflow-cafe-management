begin;

insert into public.units(code,name_th,name_en,unit_type,decimal_places,is_active)
values
('G','กรัม','Gram','WEIGHT',2),
('ML','มิลลิลิตร','Milliliter','VOLUME',2),
('TBSP','ช้อนโต๊ะ','Tablespoon','PURCHASE_UNIT',2),
('TSP','ช้อนชา','Teaspoon','PURCHASE_UNIT',2)
on conflict (code) do update set
 name_th=excluded.name_th,name_en=excluded.name_en,unit_type=excluded.unit_type,
 decimal_places=excluded.decimal_places,is_active=true,updated_at=now();

with seed(ingredient_code,name_th,name_en,unit_code,ingredient_category) as (
 values
('BLUEBERRY_SYRUP','ไซรัปบลูเบอร์รี่','Blueberry syrup','ML','SYRUP'),
('CARAMEL_SYRUP','คาราเมลไซรัป','Caramel syrup','ML','SYRUP'),
('COCOA_POWDER','ผงโกโก้','Cocoa powder','G','POWDER'),
('COCONUT_MILK','กะทิ / Coconut milk','Coconut milk','G','DAIRY_ALT'),
('COCONUT_SYRUP','ไซรัปมะพร้าว','Coconut syrup','G','SYRUP'),
('COCONUT_WATER','น้ำมะพร้าว','Coconut water','G','BEVERAGE_BASE'),
('COFFEE_BEANS','เมล็ดกาแฟ','Coffee beans','G','COFFEE'),
('CREAM_CHEESE_BASE','ครีมชีสเตรียม','Prepared cream cheese','G','PREPARED'),
('EVAPORATED_MILK','นมข้นจืด','Evaporated milk','ML','DAIRY'),
('FRESH_MILK','นมสด','Fresh milk','ML','DAIRY'),
('GRAPE_SYRUP','ไซรัปองุ่น','Grape syrup','G','SYRUP'),
('GREEN_TEA_EXTRACT','ชาเขียวสกัด','Green tea extract','ML','PREPARED'),
('HONEY','น้ำผึ้ง','Honey','G','SWEETENER'),
('JASMINE_GREEN_TEA_EXTRACT','ชาเขียว/ชาจัสมินสกัด','Green/Jasmine tea extract','G','PREPARED'),
('LEMON_JUICE','น้ำเลมอน','Lemon juice','ML','JUICE'),
('LEMON_POWDER','ผงมะนาว','Lemon powder','TSP','POWDER'),
('LYCHEE_SYRUP','ไซรัปลิ้นจี่','Lychee syrup','ML','SYRUP'),
('MATCHA_POWDER','ผงมัทฉะ','Matcha powder','G','POWDER'),
('NEUTRAL_CLOUD_BASE','Neutral Cloud Base','Neutral Cloud Base','G','PREPARED'),
('NON_DAIRY_CREAMER','ครีมเทียม','Non-dairy creamer','TBSP','POWDER'),
('ORANGE_JUICE','น้ำส้ม 100%','100% orange juice','ML','JUICE'),
('PASSION_FRUIT_PUREE','เพียวเร่เสาวรส','Passion fruit puree','G','PUREE'),
('PEACH_TEA_POWDER','ผงชาพีช','Peach tea powder','TBSP','POWDER'),
('SIMPLE_SYRUP','น้ำเชื่อม','Simple syrup','ML','SYRUP'),
('SODA','โซดา','Soda water','ML','BEVERAGE_BASE'),
('STRAWBERRY_PUREE','เพียวเร่สตรอเบอร์รี่','Strawberry puree','G','PUREE'),
('STRAWBERRY_SYRUP','ไซรัปสตรอเบอร์รี่','Strawberry syrup','ML','SYRUP'),
('SWEETENED_CONDENSED_MILK','นมข้นหวาน','Sweetened condensed milk','ML','DAIRY'),
('TAIWAN_TEA_EXTRACT','ชานมไต้หวันสกัด','Taiwan tea extract','ML','PREPARED'),
('TARO_POWDER','ผงเผือก','Taro powder','TBSP','POWDER'),
('THAI_TEA_CONCENTRATE_CLOUD','ชาไทยเข้มข้นสำหรับ Cloud','Thai tea concentrate for Cloud','G','PREPARED'),
('THAI_TEA_EXTRACT','ชาไทยสกัด','Thai tea extract','ML','PREPARED'),
('YUZU','ยูซุ','Yuzu','ML','JUICE')
)
insert into public.ingredients(ingredient_code,name_th,name_en,base_unit_id,ingredient_category,minimum_stock_level,is_active,track_stock)
select s.ingredient_code,s.name_th,s.name_en,u.id,s.ingredient_category,0,true,true
from seed s join public.units u on u.code=s.unit_code
on conflict (ingredient_code) do update set
 name_th=excluded.name_th,name_en=excluded.name_en,base_unit_id=excluded.base_unit_id,
 ingredient_category=excluded.ingredient_category,is_active=true,track_stock=true,updated_at=now();

create temporary table _recipe_seed(menu_en text primary key, recipe_name text not null, notes text);
insert into _recipe_seed(menu_en,recipe_name,notes) values
('Americano Hot','สูตรมาตรฐาน - Americano Hot','อ้างอิงไฟล์ สรุปสูตรเครื่องดื่ม_แยกหมวด_ครบตามเมนู(1).xlsx. สูตรนี้ใช้สำหรับตัดสต็อก/คำนวณต้นทุน; น้ำและน้ำแข็งไม่รวมเป็นวัตถุดิบสต็อก.'),
('Americano Cold','สูตรมาตรฐาน - Americano Cold','อ้างอิงไฟล์ สรุปสูตรเครื่องดื่ม_แยกหมวด_ครบตามเมนู(1).xlsx. ใช้ระดับหวานปกติจากไฟล์; น้ำและน้ำแข็งไม่รวมเป็นวัตถุดิบสต็อก.'),
('Espresso Hot','สูตรมาตรฐาน - Espresso Hot','อ้างอิงไฟล์ สรุปสูตรเครื่องดื่ม_แยกหมวด_ครบตามเมนู(1).xlsx.'),
('Espresso Cold','สูตรมาตรฐาน - Espresso Cold','ใช้นมผสมสูตรหวานปกติ 30 ml; ขยายเป็นนมข้นหวาน 22.5 ml + นมข้นจืด 7.5 ml ตามสูตรเตรียม 1200:400.'),
('Cappuccino Hot','สูตรมาตรฐาน - Cappuccino Hot','อ้างอิงไฟล์สูตรเครื่องดื่ม; ปริมาณนมรวมส่วนตีฟองตามสูตร.'),
('Cappuccino Cold','สูตรมาตรฐาน - Cappuccino Cold','ใช้นมผสมสูตรหวานปกติ 30 ml; ขยายเป็นวัตถุดิบฐานตามสูตรเตรียม.'),
('Latte Hot','สูตรมาตรฐาน - Latte Hot','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Latte Cold','สูตรมาตรฐาน - Latte Cold','ใช้นมผสมสูตรหวานปกติ 30 ml; ขยายเป็นวัตถุดิบฐานตามสูตรเตรียม.'),
('Mocha Cold','สูตรมาตรฐาน - Mocha Cold','ใช้นมผสมสูตรหวานปกติ 30 ml; โฟมนมที่ไม่ระบุปริมาณไม่นำมาตัดสต็อก.'),
('Coconut Coffee Cold','สูตรมาตรฐาน - Coconut Coffee Cold','ไฟล์ระบุกาแฟสกัด 36 g; ใช้ผงกาแฟ 18 g เป็น operational default และ Coconut syrup 10 g จากช่วง 8–12 g.'),
('Orange Coffee Cold','สูตรมาตรฐาน - Orange Coffee Cold','ใช้ระดับหวานปกติ 15 ml; ใช้ผงกาแฟ 18 g เป็น operational default.'),
('Fresh Milk','สูตรมาตรฐาน - Fresh Milk','Simple syrup 10 g normalised เป็น 10 ml สำหรับ stock formula.'),
('Caramel Milk','สูตรมาตรฐาน - Caramel Milk','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Taro Milk','สูตรมาตรฐาน - Taro Milk','นมผสม 20 ml ขยายตามอัตรา 1200:400; Simple syrup เลือก 10 จากช่วง 5–10 g.'),
('Strawberry Milk','สูตรมาตรฐาน - Strawberry Milk','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Honey Milk','สูตรมาตรฐาน - Honey Milk','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Cocoa','สูตรมาตรฐาน - Cocoa','ใช้นมผสมสูตรหวานปกติ; 1 ช้อนโต๊ะโกโก้ใช้ operational standard 5 g.'),
('Thai Milk Tea','สูตรมาตรฐาน - Thai Milk Tea','ใช้นมผสมสูตรหวานปกติ 30 ml และน้ำเชื่อมหวานปกติ 10 ml.'),
('Green Milk Tea','สูตรมาตรฐาน - Green Milk Tea','ใช้นมผสมสูตรหวานปกติ 30 ml.'),
('Taiwanese Milk Tea','สูตรมาตรฐาน - Taiwanese Milk Tea','ใช้นมผสมสูตรหวานปกติ 30 ml และน้ำเชื่อมหวานปกติ 10 ml.'),
('Lemon Tea','สูตรมาตรฐาน - Lemon Tea','ใช้ระดับหวานปกติ 50 ml.'),
('Peach Tea','สูตรมาตรฐาน - Peach Tea','ใช้ระดับหวานปกติ 10 ml.'),
('Grape Tea','สูตรมาตรฐาน - Grape Tea','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Pure Matcha','สูตรมาตรฐาน - Pure Matcha','1 ช้อนชา Matcha = 2 g operational standard; ใช้หวานปกติ 20 ml.'),
('Matcha Latte','สูตรมาตรฐาน - Matcha Latte','2 ช้อนชา Matcha = 4 g operational standard; ใช้นมผสมสูตรหวานปกติ 30 ml.'),
('Strawberry Matcha','สูตรมาตรฐาน - Strawberry Matcha','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Coconut Matcha','สูตรมาตรฐาน - Coconut Matcha','Simple syrup เลือก 10 จากช่วง 5–10 g.'),
('Orange Matcha','สูตรมาตรฐาน - Orange Matcha','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('River Flow','สูตรมาตรฐาน - River Flow','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Pink River','สูตรมาตรฐาน - Pink River','Strawberry puree 20 ml normalised เป็น 20 g operationally.'),
('Golden Flow','สูตรมาตรฐาน - Golden Flow','Passion fruit puree 25 ml normalised เป็น 25 g operationally.'),
('Lychee Breeze','สูตรมาตรฐาน - Lychee Breeze','อ้างอิงไฟล์สูตรเครื่องดื่ม.'),
('Sunset by the River','สูตรมาตรฐาน - Sunset by the River','Passion fruit puree 20 ml normalised เป็น 20 g operationally.'),
('Grape Tea Smoothie Cream Cheese','สูตรมาตรฐาน - Grape Tea Smoothie Cream Cheese','น้ำแข็งไม่รวมใน stock formula.'),
('Blueberry Cheesecake Smoothie','สูตรมาตรฐาน - Blueberry Cheesecake Smoothie','รวม fresh milk 40 ml + ปริมาณสำหรับโฟมนม 40 ml; ครีมชีส 2 ช้อน/โซดาเล็กน้อย/คุกกี้ยังไม่รวมเพราะไม่ระบุหน่วยมาตรฐาน.'),
('Strawberry Cheesecake Smoothie','สูตรมาตรฐาน - Strawberry Cheesecake Smoothie','รวม fresh milk 40 ml + ปริมาณสำหรับโฟมนม 40 ml; ครีมชีส 2 ช้อน/โซดาเล็กน้อย/คุกกี้ยังไม่รวมเพราะไม่ระบุหน่วยมาตรฐาน.'),
('Coconut Thai Tea Cloud','สูตรมาตรฐาน - Coconut Thai Tea Cloud','สูตรล่าสุดไม่ใส่ Coconut milk; ใช้ Neutral Cloud Base 50 g.'),
('Coconut Matcha Cloud','สูตรมาตรฐาน - Coconut Matcha Cloud','สูตรล่าสุดไม่ใส่ Coconut milk; ใช้ Neutral Cloud Base 50 g.'),
('Coconut Cocoa Cloud','สูตรมาตรฐาน - Coconut Cocoa Cloud','สูตรล่าสุดไม่ใส่ Coconut milk; ใช้ Neutral Cloud Base 50 g.');

insert into public.recipes(menu_item_id,recipe_name,version_no,yield_quantity,effective_from,effective_to,status,notes)
select m.id,s.recipe_name,1,1,date '2026-09-10',null,'ACTIVE'::recipe_status,s.notes
from _recipe_seed s join public.menu_items m on m.name_en=s.menu_en
on conflict (menu_item_id,version_no) do update set
 recipe_name=excluded.recipe_name,yield_quantity=1,effective_from=excluded.effective_from,effective_to=null,
 status='ACTIVE'::recipe_status,notes=excluded.notes,updated_at=now();

delete from public.recipe_items ri
using public.recipes r, public.menu_items m, _recipe_seed s
where ri.recipe_id=r.id and r.menu_item_id=m.id and m.name_en=s.menu_en and r.version_no=1;

create temporary table _recipe_line_seed(menu_en text, ingredient_code text, quantity numeric, display_order int);
insert into _recipe_line_seed(menu_en,ingredient_code,quantity,display_order) values
('Americano Hot','COFFEE_BEANS',18,1),('Americano Cold','COFFEE_BEANS',18,1),('Americano Cold','SIMPLE_SYRUP',20,2),('Espresso Hot','COFFEE_BEANS',22,1),('Espresso Cold','COFFEE_BEANS',22,1),('Espresso Cold','EVAPORATED_MILK',37.5,2),('Espresso Cold','NON_DAIRY_CREAMER',1,3),('Espresso Cold','SWEETENED_CONDENSED_MILK',22.5,4),
('Cappuccino Hot','COFFEE_BEANS',22,1),('Cappuccino Hot','FRESH_MILK',150,2),('Cappuccino Cold','COFFEE_BEANS',22,1),('Cappuccino Cold','EVAPORATED_MILK',37.5,2),('Cappuccino Cold','NON_DAIRY_CREAMER',2,3),('Cappuccino Cold','SWEETENED_CONDENSED_MILK',22.5,4),
('Latte Hot','COFFEE_BEANS',18,1),('Latte Hot','FRESH_MILK',150,2),('Latte Cold','COFFEE_BEANS',18,1),('Latte Cold','FRESH_MILK',30,2),('Latte Cold','EVAPORATED_MILK',37.5,3),('Latte Cold','SWEETENED_CONDENSED_MILK',22.5,4),
('Mocha Cold','COFFEE_BEANS',22,1),('Mocha Cold','EVAPORATED_MILK',37.5,2),('Mocha Cold','NON_DAIRY_CREAMER',1,3),('Mocha Cold','SWEETENED_CONDENSED_MILK',22.5,4),('Mocha Cold','COCOA_POWDER',5,5),
('Coconut Coffee Cold','COFFEE_BEANS',18,1),('Coconut Coffee Cold','FRESH_MILK',100,2),('Coconut Coffee Cold','COCONUT_MILK',45,3),('Coconut Coffee Cold','COCONUT_SYRUP',10,4),('Orange Coffee Cold','COFFEE_BEANS',18,1),('Orange Coffee Cold','ORANGE_JUICE',90,2),('Orange Coffee Cold','SIMPLE_SYRUP',15,3),
('Fresh Milk','FRESH_MILK',160,1),('Fresh Milk','SIMPLE_SYRUP',10,2),('Caramel Milk','FRESH_MILK',150,1),('Caramel Milk','EVAPORATED_MILK',30,2),('Caramel Milk','CARAMEL_SYRUP',20,3),
('Taro Milk','FRESH_MILK',60,1),('Taro Milk','EVAPORATED_MILK',35,2),('Taro Milk','SWEETENED_CONDENSED_MILK',15,3),('Taro Milk','NON_DAIRY_CREAMER',1,4),('Taro Milk','TARO_POWDER',1,5),('Taro Milk','SIMPLE_SYRUP',10,6),
('Strawberry Milk','FRESH_MILK',160,1),('Strawberry Milk','STRAWBERRY_PUREE',45,2),('Honey Milk','FRESH_MILK',160,1),('Honey Milk','HONEY',20,2),
('Cocoa','FRESH_MILK',60,1),('Cocoa','EVAPORATED_MILK',37.5,2),('Cocoa','SWEETENED_CONDENSED_MILK',22.5,3),('Cocoa','NON_DAIRY_CREAMER',1,4),('Cocoa','COCOA_POWDER',5,5),
('Thai Milk Tea','THAI_TEA_EXTRACT',50,1),('Thai Milk Tea','NON_DAIRY_CREAMER',1,2),('Thai Milk Tea','EVAPORATED_MILK',37.5,3),('Thai Milk Tea','SWEETENED_CONDENSED_MILK',22.5,4),('Thai Milk Tea','SIMPLE_SYRUP',10,5),
('Green Milk Tea','GREEN_TEA_EXTRACT',50,1),('Green Milk Tea','NON_DAIRY_CREAMER',1,2),('Green Milk Tea','EVAPORATED_MILK',37.5,3),('Green Milk Tea','SWEETENED_CONDENSED_MILK',22.5,4),
('Taiwanese Milk Tea','TAIWAN_TEA_EXTRACT',50,1),('Taiwanese Milk Tea','NON_DAIRY_CREAMER',2,2),('Taiwanese Milk Tea','EVAPORATED_MILK',37.5,3),('Taiwanese Milk Tea','SWEETENED_CONDENSED_MILK',22.5,4),('Taiwanese Milk Tea','SIMPLE_SYRUP',10,5),
('Lemon Tea','THAI_TEA_EXTRACT',100,1),('Lemon Tea','LEMON_POWDER',1,2),('Lemon Tea','SIMPLE_SYRUP',50,3),('Peach Tea','PEACH_TEA_POWDER',1,1),('Peach Tea','SIMPLE_SYRUP',10,2),('Grape Tea','JASMINE_GREEN_TEA_EXTRACT',100,1),('Grape Tea','GRAPE_SYRUP',30,2),
('Pure Matcha','MATCHA_POWDER',2,1),('Pure Matcha','SIMPLE_SYRUP',20,2),('Matcha Latte','MATCHA_POWDER',4,1),('Matcha Latte','FRESH_MILK',85,2),('Matcha Latte','EVAPORATED_MILK',47.5,3),('Matcha Latte','SWEETENED_CONDENSED_MILK',22.5,4),
('Strawberry Matcha','MATCHA_POWDER',3,1),('Strawberry Matcha','FRESH_MILK',130,2),('Strawberry Matcha','STRAWBERRY_PUREE',40,3),('Coconut Matcha','MATCHA_POWDER',3,1),('Coconut Matcha','COCONUT_WATER',110,2),('Coconut Matcha','COCONUT_MILK',30,3),('Coconut Matcha','SIMPLE_SYRUP',10,4),('Orange Matcha','MATCHA_POWDER',3,1),('Orange Matcha','ORANGE_JUICE',100,2),('Orange Matcha','SIMPLE_SYRUP',5,3),
('River Flow','YUZU',25,1),('River Flow','LEMON_JUICE',10,2),('River Flow','SIMPLE_SYRUP',5,3),('River Flow','SODA',120,4),('Pink River','LEMON_JUICE',8,1),('Pink River','STRAWBERRY_PUREE',20,2),('Pink River','LYCHEE_SYRUP',15,3),('Pink River','SODA',120,4),('Golden Flow','PASSION_FRUIT_PUREE',25,1),('Golden Flow','ORANGE_JUICE',40,2),('Golden Flow','SIMPLE_SYRUP',5,3),('Golden Flow','SODA',90,4),('Lychee Breeze','LEMON_JUICE',10,1),('Lychee Breeze','LYCHEE_SYRUP',25,2),('Lychee Breeze','SODA',125,3),('Sunset by the River','STRAWBERRY_SYRUP',15,1),('Sunset by the River','PASSION_FRUIT_PUREE',20,2),('Sunset by the River','ORANGE_JUICE',50,3),('Sunset by the River','SODA',80,4),
('Grape Tea Smoothie Cream Cheese','JASMINE_GREEN_TEA_EXTRACT',100,1),('Grape Tea Smoothie Cream Cheese','GRAPE_SYRUP',30,2),('Grape Tea Smoothie Cream Cheese','SIMPLE_SYRUP',5,3),('Grape Tea Smoothie Cream Cheese','CREAM_CHEESE_BASE',50,4),('Blueberry Cheesecake Smoothie','BLUEBERRY_SYRUP',20,1),('Blueberry Cheesecake Smoothie','SWEETENED_CONDENSED_MILK',22.5,2),('Blueberry Cheesecake Smoothie','EVAPORATED_MILK',7.5,3),('Blueberry Cheesecake Smoothie','FRESH_MILK',80,4),('Strawberry Cheesecake Smoothie','STRAWBERRY_SYRUP',20,1),('Strawberry Cheesecake Smoothie','SWEETENED_CONDENSED_MILK',22.5,2),('Strawberry Cheesecake Smoothie','EVAPORATED_MILK',7.5,3),('Strawberry Cheesecake Smoothie','FRESH_MILK',80,4),
('Coconut Thai Tea Cloud','COCONUT_WATER',105,1),('Coconut Thai Tea Cloud','SIMPLE_SYRUP',5,2),('Coconut Thai Tea Cloud','NEUTRAL_CLOUD_BASE',50,3),('Coconut Thai Tea Cloud','THAI_TEA_CONCENTRATE_CLOUD',12,4),('Coconut Matcha Cloud','COCONUT_WATER',105,1),('Coconut Matcha Cloud','SIMPLE_SYRUP',5,2),('Coconut Matcha Cloud','NEUTRAL_CLOUD_BASE',50,3),('Coconut Matcha Cloud','MATCHA_POWDER',1,4),('Coconut Cocoa Cloud','COCONUT_WATER',105,1),('Coconut Cocoa Cloud','SIMPLE_SYRUP',5,2),('Coconut Cocoa Cloud','NEUTRAL_CLOUD_BASE',50,3),('Coconut Cocoa Cloud','COCOA_POWDER',3,4);

insert into public.recipe_items(recipe_id,ingredient_id,quantity,unit_id,wastage_percentage,display_order)
select r.id,i.id,l.quantity,i.base_unit_id,0,l.display_order
from _recipe_line_seed l
join public.menu_items m on m.name_en=l.menu_en
join public.recipes r on r.menu_item_id=m.id and r.version_no=1
join public.ingredients i on i.ingredient_code=l.ingredient_code;

update public.menu_items m
set default_recipe_id=r.id,updated_at=now()
from public.recipes r,_recipe_seed s
where r.menu_item_id=m.id and r.version_no=1 and m.name_en=s.menu_en;

drop table _recipe_line_seed;
drop table _recipe_seed;

commit;
