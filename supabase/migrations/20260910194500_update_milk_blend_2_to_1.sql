-- Update prepared milk blend to 2:1: sweetened condensed milk 100 ml + evaporated milk 50 ml.
-- Existing recipes store the blend expanded into the two physical ingredients so stock deduction remains traceable.

with target(menu_en, sweet_qty, evap_qty) as (
  values
    ('Espresso Cold',20.0000,40.0000),
    ('Cappuccino Cold',20.0000,40.0000),
    ('Latte Cold',20.0000,40.0000),
    ('Mocha Cold',20.0000,40.0000),
    ('Cocoa',20.0000,40.0000),
    ('Matcha Latte',20.0000,50.0000),
    ('Thai Milk Tea',20.0000,40.0000),
    ('Green Milk Tea',20.0000,40.0000),
    ('Taiwanese Milk Tea',20.0000,40.0000),
    ('Blueberry Cheesecake Smoothie',20.0000,10.0000),
    ('Strawberry Cheesecake Smoothie',20.0000,10.0000),
    ('Taro Milk',13.3333,36.6667)
), recipe_target as (
  select r.id as recipe_id, t.sweet_qty, t.evap_qty
  from target t
  join public.menu_items mi on mi.name_en=t.menu_en
  join public.recipes r on r.menu_item_id=mi.id and r.status='ACTIVE'
)
update public.recipe_items ri
set quantity = case
  when i.name_th='นมข้นหวาน' then rt.sweet_qty
  when i.name_th='นมข้นจืด' then rt.evap_qty
  else ri.quantity
end,
updated_at=now()
from recipe_target rt, public.ingredients i
where ri.recipe_id=rt.recipe_id
  and i.id=ri.ingredient_id
  and i.name_th in ('นมข้นหวาน','นมข้นจืด');

update public.recipes
set notes = replace(replace(notes,
  'นมข้นหวาน 75% + นมข้นจืด 25% ตามสูตรเตรียม 1200:400',
  'นมข้นหวาน 66.67% + นมข้นจืด 33.33% ตามสูตรเตรียม 100:50'),
  'นมข้นหวาน 75% + นมข้นจืด 25%',
  'นมข้นหวาน 66.67% + นมข้นจืด 33.33%'),
updated_at=now()
where status='ACTIVE' and notes like '%นมผสม%';
