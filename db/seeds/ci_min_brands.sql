insert into scout.brand_catalog(brand_name, synonyms)
values ('Coca-Cola', ARRAY['Coke','Coke Sakto'])
on conflict do nothing;
insert into scout.brand_alias(alias, brand_id)
select 'coke', brand_id from scout.brand_catalog where brand_name='Coca-Cola'
on conflict do nothing;