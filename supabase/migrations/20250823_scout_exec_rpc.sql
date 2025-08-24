-- ===========================================================
-- Scout v5.2 — SQL Exec RPC for Monitors
-- ===========================================================

-- Create a trusted SQL runner for monitor definitions
-- This is SECURITY DEFINER so it runs with owner privileges
-- Only allows execution of SQL from platinum_monitors table
create or replace function scout.exec(query text)
returns jsonb
language plpgsql
security definer
set search_path = scout, public
as $$
declare
  result jsonb;
  monitor_exists boolean;
begin
  -- Security check: only allow SQL that exists in platinum_monitors
  select exists(
    select 1 from scout.platinum_monitors 
    where definition_sql = query 
    and is_enabled = true
  ) into monitor_exists;
  
  if not monitor_exists then
    raise exception 'Unauthorized SQL: query must exist in platinum_monitors';
  end if;
  
  -- Execute the query and return results as JSONB
  execute format('select jsonb_agg(row_to_json(t)) from (%s) t', query) into result;
  
  return coalesce(result, '[]'::jsonb);
exception
  when others then
    -- Log error but don't expose internal details
    raise warning 'Monitor SQL execution failed: %', sqlerrm;
    return jsonb_build_object('error', 'Monitor execution failed');
end;
$$;

-- Grant execute permission to authenticated users
grant execute on function scout.exec(text) to authenticated;

-- Also create RPC for getting products needing Isko (used by agentic-cron)
create or replace function scout.get_products_needing_isko(p_limit int default 25)
returns table(
  brand_id uuid,
  product_id uuid, 
  product_name text,
  scrape_url text
)
language sql
security definer
as $$
  -- Find products without recent scraping (>7 days old or never scraped)
  select 
    p.brand_id,
    p.id as product_id,
    p.product_name,
    coalesce(p.scrape_url, 'https://scout.ai/isko/' || p.id) as scrape_url
  from masterdata.products p
  left join lateral (
    select max(created_at) as last_scraped
    from deep_research.sku_summary s
    where s.product_id = p.id
  ) recent on true
  where p.is_active = true
  and (recent.last_scraped is null or recent.last_scraped < current_timestamp - interval '7 days')
  order by p.priority desc nulls last, random()
  limit p_limit;
$$;

grant execute on function scout.get_products_needing_isko(int) to authenticated;