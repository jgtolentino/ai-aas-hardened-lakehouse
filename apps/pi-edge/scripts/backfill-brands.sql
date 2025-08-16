-- Scout Edge: Emergency Brand Backfill Script
-- This addresses TBWA's finding: "99.67% brand data missing"

create schema if not exists suqi;

-- Philippine brand catalog for backfill
create table if not exists suqi.ph_brand_catalog (
  keyword text primary key,
  brand_name text not null,
  category text not null,
  confidence numeric check (confidence>=0 and confidence<=1),
  tbwa_client boolean default false
);

-- Insert common PH brands (extend this list based on your data)
insert into suqi.ph_brand_catalog(keyword,brand_name,category,confidence,tbwa_client) values
  ('coke','Coca-Cola','Beverages',0.95,false),
  ('coca-cola','Coca-Cola','Beverages',0.95,false),
  ('pepsi','Pepsi','Beverages',0.95,false),
  ('sprite','Sprite','Beverages',0.94,false),
  ('royal','Royal','Beverages',0.92,false),
  ('lucky me','Lucky Me','Instant Noodles',0.92,false),
  ('nissin','Nissin','Instant Noodles',0.92,false),
  ('payless','Payless','Instant Noodles',0.90,false),
  ('marlboro','Marlboro','Tobacco',0.95,false),
  ('safeguard','Safeguard','Personal Care',0.93,false),
  ('palmolive','Palmolive','Personal Care',0.92,false),
  ('tide','Tide','Household',0.94,false),
  ('ariel','Ariel','Household',0.93,false),
  ('downy','Downy','Household',0.92,false),
  ('smart','Smart','Telecom',0.95,false),
  ('globe','Globe','Telecom',0.95,false),
  ('nestle','Nestle','Food',0.95,false),
  ('nescafe','Nescafe','Beverages',0.94,false),
  ('milo','Milo','Beverages',0.93,false),
  ('bear brand','Bear Brand','Dairy',0.92,false),
  ('alaska','Alaska','Dairy',0.91,false),
  ('magnolia','Magnolia','Food',0.93,false),
  ('purefoods','Purefoods','Food',0.94,false),
  ('san miguel','San Miguel','Beverages',0.95,false),
  ('red horse','Red Horse','Beverages',0.93,false),
  ('tanduay','Tanduay','Beverages',0.94,false),
  ('emperador','Emperador','Beverages',0.92,false),
  ('kopiko','Kopiko','Beverages',0.91,false),
  ('yakult','Yakult','Beverages',0.90,false),
  ('oishi','Oishi','Snacks',0.91,false),
  ('jack n jill','Jack n Jill','Snacks',0.92,false),
  ('rebisco','Rebisco','Snacks',0.91,false),
  ('skyflakes','SkyFlakes','Snacks',0.90,false),
  ('fita','Fita','Snacks',0.89,false),
  ('chippy','Chippy','Snacks',0.90,false),
  ('nova','Nova','Snacks',0.89,false),
  ('piattos','Piattos','Snacks',0.90,false),
  ('colgate','Colgate','Personal Care',0.95,false),
  ('close up','Close Up','Personal Care',0.91,false),
  ('sensodyne','Sensodyne','Personal Care',0.90,false),
  ('head & shoulders','Head & Shoulders','Personal Care',0.92,false),
  ('rejoice','Rejoice','Personal Care',0.90,false),
  ('sunsilk','Sunsilk','Personal Care',0.91,false),
  ('dove','Dove','Personal Care',0.93,false),
  ('nivea','Nivea','Personal Care',0.92,false),
  ('rexona','Rexona','Personal Care',0.91,false),
  ('modess','Modess','Personal Care',0.90,false),
  ('whisper','Whisper','Personal Care',0.90,false),
  ('pampers','Pampers','Baby Care',0.93,false),
  ('huggies','Huggies','Baby Care',0.92,false),
  ('eq','EQ','Baby Care',0.88,false),
  ('lactum','Lactum','Baby Care',0.91,false),
  ('promil','Promil','Baby Care',0.92,false),
  ('enfagrow','Enfagrow','Baby Care',0.91,false),
  ('cerelac','Cerelac','Baby Care',0.90,false),
  ('gerber','Gerber','Baby Care',0.89,false),
  ('biogesic','Biogesic','Medicine',0.94,false),
  ('paracetamol','Paracetamol','Medicine',0.92,false),
  ('neozep','Neozep','Medicine',0.91,false),
  ('bioflu','Bioflu','Medicine',0.90,false),
  ('alaxan','Alaxan','Medicine',0.89,false),
  ('medicol','Medicol','Medicine',0.88,false),
  ('tempra','Tempra','Medicine',0.89,false),
  ('solmux','Solmux','Medicine',0.90,false),
  ('robitussin','Robitussin','Medicine',0.89,false),
  ('enervon','Enervon','Medicine',0.91,false),
  ('centrum','Centrum','Medicine',0.90,false),
  ('stresstabs','Stresstabs','Medicine',0.88,false)
on conflict do nothing;

-- Backfill brand/category where missing or null
with hits as (
  select i.id, i.transaction_id, i.product_name, i.local_name,
         c.brand_name, c.category, c.confidence
  from public.scout_gold_transaction_items i
  join suqi.ph_brand_catalog c
    on lower(coalesce(i.product_name,'')) like '%'||c.keyword||'%'
    or lower(coalesce(i.local_name,''))  like '%'||c.keyword||'%'
  where (i.brand_name is null)
)
update public.scout_gold_transaction_items i
   set brand_name   = h.brand_name,
       category_name= coalesce(i.category_name, h.category),
       confidence   = greatest(coalesce(i.confidence,0), h.confidence)
from hits h
where h.id = i.id;

-- Report results
select
  count(*)                                       as items_total,
  sum( (brand_name is null)::int )               as brands_missing,
  round(100.0*avg( (brand_name is null)::int ),2) as brands_missing_pct
from public.scout_gold_transaction_items;