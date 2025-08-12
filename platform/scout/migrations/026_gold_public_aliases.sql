-- 026_gold_public_aliases.sql
-- Create public alias views for Gold layer to expose via PostgREST
-- This allows PostgREST to serve scout schema views through public schema

-- Drop existing aliases if they exist
DROP VIEW IF EXISTS public.gold_txn_items_api CASCADE;
DROP VIEW IF EXISTS public.gold_sales_day_api CASCADE;
DROP VIEW IF EXISTS public.gold_brand_mix_api CASCADE;
DROP VIEW IF EXISTS public.gold_geo_sales_api CASCADE;

-- Create public alias views that select from scout schema
CREATE OR REPLACE VIEW public.gold_txn_items_api AS 
SELECT * FROM scout.gold_txn_items;

CREATE OR REPLACE VIEW public.gold_sales_day_api AS 
SELECT * FROM scout.gold_sales_day;

CREATE OR REPLACE VIEW public.gold_brand_mix_api AS 
SELECT * FROM scout.gold_brand_mix;

CREATE OR REPLACE VIEW public.gold_geo_sales_api AS 
SELECT * FROM scout.gold_geo_sales;

-- Grant SELECT permissions to authenticated users
GRANT SELECT ON public.gold_txn_items_api TO authenticated;
GRANT SELECT ON public.gold_sales_day_api TO authenticated;
GRANT SELECT ON public.gold_brand_mix_api TO authenticated;
GRANT SELECT ON public.gold_geo_sales_api TO authenticated;

-- Also grant to anon for public dashboards (optional)
GRANT SELECT ON public.gold_txn_items_api TO anon;
GRANT SELECT ON public.gold_sales_day_api TO anon;
GRANT SELECT ON public.gold_brand_mix_api TO anon;
GRANT SELECT ON public.gold_geo_sales_api TO anon;

-- Add comments for documentation
COMMENT ON VIEW public.gold_txn_items_api IS 'Public alias for scout.gold_txn_items - transaction line items with full denormalization';
COMMENT ON VIEW public.gold_sales_day_api IS 'Public alias for scout.gold_sales_day - daily sales aggregates by store/brand/category';
COMMENT ON VIEW public.gold_brand_mix_api IS 'Public alias for scout.gold_brand_mix - brand market share analysis';
COMMENT ON VIEW public.gold_geo_sales_api IS 'Public alias for scout.gold_geo_sales - geographic sales performance';