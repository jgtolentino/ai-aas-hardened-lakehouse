-- Scout Edge: Smoke Test Data for Initial Testing

-- Create a test source if needed
insert into scout.source_registry (source_id, source_name, source_type, domain, selectors, rate_limit_ms)
values (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Test E-commerce Site',
  'ecommerce',
  'example.com',
  jsonb_build_object(
    'start', '["https://example.com/collections/noodles", "https://example.com/collections/beverages"]',
    'product_title', 'h1.product-title',
    'product_price', 'span.price',
    'product_brand', 'span.brand'
  ),
  2000
) on conflict (source_id) do nothing;

-- Seed some initial test jobs
insert into scout.scraping_jobs(source_id, url, priority, depth)
values
  ('00000000-0000-0000-0000-000000000001', 'https://example.com/collections/noodles', 3, 0),
  ('00000000-0000-0000-0000-000000000001', 'https://example.com/products/pancit-canton-original', 5, 1),
  ('00000000-0000-0000-0000-000000000001', 'https://example.com/products/lucky-me-beef', 5, 1),
  ('00000000-0000-0000-0000-000000000001', 'https://example.com/collections/beverages', 3, 0),
  ('00000000-0000-0000-0000-000000000001', 'https://example.com/products/coca-cola-1l', 5, 1)
on conflict do nothing;

-- Function to generate synthetic test data
create or replace function scout.generate_test_results(p_count int default 10)
returns void language plpgsql as $$
declare 
  i int;
  v_job_id bigint;
  v_source_id uuid;
  v_url text;
begin
  for i in 1..p_count loop
    -- Get a random queued job
    select job_id, source_id, url into v_job_id, v_source_id, v_url
    from scout.scraping_jobs 
    where status='queued'
    order by random()
    limit 1;
    
    if v_job_id is null then
      raise notice 'No queued jobs to process';
      return;
    end if;
    
    -- Simulate successful scrape
    perform scout.report_job_result(
      p_job_id => v_job_id,
      p_http_status => 200,
      p_etag => null,
      p_last_modified => null,
      p_content_sha256 => encode(sha256(random()::text::bytea), 'hex'),
      p_parse_status => 'ok',
      p_parse_note => 'synthetic test data',
      p_discovered => array[
        v_url || '/variant-1',
        v_url || '/variant-2'
      ]
    );
    
    -- Generate some synthetic items
    if v_url like '%/products/%' then
      insert into scout.master_items(
        source_id, source_url, brand_name, product_name, 
        pack_size_value, pack_size_unit, list_price
      )
      values (
        v_source_id,
        v_url,
        case (i % 4)
          when 0 then 'LUCKY ME'
          when 1 then 'NISSIN'
          when 2 then 'COCA COLA'
          else 'SAN MIGUEL'
        end,
        'Test Product ' || i,
        case when i % 3 = 0 then 100 else 50 end,
        case when i % 3 = 0 then 'g' else 'ml' end,
        (10 + random() * 90)::numeric(10,2)
      );
    end if;
  end loop;
end$$;

-- Quick test execution
select 'Test data seeded. Run these commands to test:' as instruction
union all
select '1. Check queue status: SELECT * FROM scout.dashboard_snapshot();'
union all  
select '2. Process some jobs: SELECT scout.generate_test_results(5);'
union all
select '3. Check results: SELECT * FROM scout.v_master_items_recent;';