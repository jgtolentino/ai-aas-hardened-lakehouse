-- Scout Edge: Server-Side Brand Resolver
-- Automatically standardizes and resolves brands on insert

-- Canonical brand resolver using variants and fuzzy matching
create or replace function scout.brand_resolve(input text)
returns text language plpgsql immutable as $$
declare
  x text := scout.norm_brand(input);
  hit text;
begin
  if x is null or x='' then
    return null;
  end if;

  -- 1) Exact brand hit
  select brand into hit
  from scout.v_brand_universe
  where brand = x
  limit 1;
  if hit is not null then return hit; end if;

  -- 2) Variant exact match
  select brand into hit
  from scout.v_variant_index
  where variant_norm = x
  limit 1;
  if hit is not null then return hit; end if;

  -- 3) Fuzzy match over variants (threshold 0.55)
  select brand into hit
  from scout.v_variant_index
  where similarity(variant_norm, x) >= 0.55
  order by similarity(variant_norm, x) desc
  limit 1;
  if hit is not null then return hit; end if;

  -- 4) Fuzzy match over brand universe (threshold 0.60)
  select brand into hit
  from scout.v_brand_universe
  where similarity(brand, x) >= 0.60
  order by similarity(brand, x) desc
  limit 1;

  return hit;  -- may be null if nothing meets thresholds
end;
$$;

-- BEFORE INSERT trigger to normalize and fill brand_name
create or replace function scout.trg_items_brand_resolve()
returns trigger language plpgsql as $$
begin
  -- Try to resolve the provided brand_name
  if new.brand_name is not null then
    new.brand_name := scout.brand_resolve(new.brand_name);
  end if;
  
  -- If still null, try to extract from local_name
  if new.brand_name is null and new.local_name is not null then
    new.brand_name := scout.brand_resolve(new.local_name);
  end if;
  
  -- If still null, try to extract from product_name
  if new.brand_name is null and new.product_name is not null then
    new.brand_name := scout.brand_resolve(new.product_name);
  end if;
  
  -- Update confidence if brand was resolved
  if new.brand_name is not null and old.brand_name is null then
    -- Boost confidence slightly when brand is resolved
    new.confidence := least(new.confidence * 1.1, 1.0);
  end if;
  
  return new;
end;
$$;

-- Install the trigger
drop trigger if exists trg_items_brand_resolve on public.scout_gold_transaction_items;
create trigger trg_items_brand_resolve
before insert on public.scout_gold_transaction_items
for each row
execute function scout.trg_items_brand_resolve();

-- Optional: Batch resolver for existing data
create or replace function scout.backfill_resolve_brands(
  batch_size int default 1000
) returns table(updated_count bigint) as $$
declare
  total_updated bigint := 0;
  batch_updated bigint;
begin
  loop
    with candidates as (
      select id, product_name, local_name
      from public.scout_gold_transaction_items
      where brand_name is null
        and (product_name is not null or local_name is not null)
      limit batch_size
      for update skip locked
    ),
    updates as (
      update public.scout_gold_transaction_items i
      set brand_name = coalesce(
        scout.brand_resolve(c.product_name),
        scout.brand_resolve(c.local_name)
      ),
      confidence = case 
        when coalesce(
          scout.brand_resolve(c.product_name),
          scout.brand_resolve(c.local_name)
        ) is not null 
        then least(i.confidence * 1.1, 1.0)
        else i.confidence
      end
      from candidates c
      where i.id = c.id
        and coalesce(
          scout.brand_resolve(c.product_name),
          scout.brand_resolve(c.local_name)
        ) is not null
      returning 1
    )
    select count(*) into batch_updated from updates;
    
    exit when batch_updated = 0;
    total_updated := total_updated + batch_updated;
  end loop;
  
  return query select total_updated;
end;
$$ language plpgsql;