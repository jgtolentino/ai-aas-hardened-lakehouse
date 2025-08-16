-- Scout Edge: Token Mining from Transcripts
-- Advanced brand extraction from conversation transcripts

-- Token-based brand mining function
create or replace function scout.mine_brands_from_transcript(p_transaction_id text)
returns table(brand text, confidence numeric) as $$
declare
  transcript_text text;
begin
  -- Aggregate all transcript text for this transaction
  select string_agg(text, ' ' order by t_seconds) into transcript_text
  from suqi.staging_transcripts
  where transaction_id = p_transaction_id;
  
  if transcript_text is null then
    return;
  end if;
  
  -- Normalize transcript
  transcript_text := scout.norm_brand(transcript_text);
  
  -- Find all matching brands and variants
  return query
  with matches as (
    -- Direct brand matches
    select distinct 
      u.brand,
      0.95 as confidence
    from scout.v_brand_universe u
    where transcript_text like '%' || u.brand || '%'
    
    union all
    
    -- Variant matches
    select distinct
      v.brand,
      0.90 as confidence  
    from scout.v_variant_index v
    where transcript_text like '%' || v.variant_norm || '%'
  )
  select 
    m.brand,
    max(m.confidence) as confidence
  from matches m
  group by m.brand
  order by confidence desc, brand;
end;
$$ language plpgsql;

-- Enhanced trigger that mines tokens from transcripts
create or replace function scout.trg_items_brand_resolve_with_mining()
returns trigger language plpgsql as $$
declare
  mined_brand text;
  mined_confidence numeric;
begin
  -- First try standard resolution
  if new.brand_name is not null then
    new.brand_name := scout.brand_resolve(new.brand_name);
  end if;
  
  if new.brand_name is null and new.local_name is not null then
    new.brand_name := scout.brand_resolve(new.local_name);
  end if;
  
  if new.brand_name is null and new.product_name is not null then
    new.brand_name := scout.brand_resolve(new.product_name);
  end if;
  
  -- If still null, try mining from transcript
  if new.brand_name is null then
    select brand, confidence into mined_brand, mined_confidence
    from scout.mine_brands_from_transcript(new.transaction_id)
    limit 1;
    
    if mined_brand is not null then
      new.brand_name := mined_brand;
      -- Adjust confidence based on mining confidence
      new.confidence := new.confidence * mined_confidence;
    end if;
  end if;
  
  -- Update confidence if brand was resolved
  if new.brand_name is not null and old.brand_name is null then
    new.confidence := least(new.confidence * 1.1, 1.0);
  end if;
  
  return new;
end;
$$;

-- Create view for transcript brand coverage
create or replace view scout.v_transcript_brand_coverage as
with transcript_brands as (
  select 
    st.transaction_id,
    mb.brand,
    max(mb.confidence) as confidence
  from suqi.staging_transcripts st
  cross join lateral scout.mine_brands_from_transcript(st.transaction_id) mb
  group by st.transaction_id, mb.brand
),
item_brands as (
  select 
    transaction_id,
    array_agg(distinct brand_name order by brand_name) 
      filter (where brand_name is not null) as item_brands
  from public.scout_gold_transaction_items
  group by transaction_id
)
select 
  tb.transaction_id,
  tb.brand as transcript_brand,
  tb.confidence as transcript_confidence,
  ib.item_brands,
  tb.brand = any(ib.item_brands) as brand_captured
from transcript_brands tb
left join item_brands ib using (transaction_id)
order by tb.confidence desc, tb.transaction_id;

-- Mining effectiveness report
create or replace view scout.v_mining_effectiveness as
select 
  count(distinct transaction_id) as transactions_with_transcripts,
  count(distinct transaction_id) filter (where brand_captured) as brands_captured,
  round(100.0 * count(distinct transaction_id) filter (where brand_captured) / 
        nullif(count(distinct transaction_id), 0), 2) as capture_rate_pct,
  avg(transcript_confidence) filter (where brand_captured) as avg_confidence_captured,
  count(distinct transcript_brand) as unique_brands_mined
from scout.v_transcript_brand_coverage;