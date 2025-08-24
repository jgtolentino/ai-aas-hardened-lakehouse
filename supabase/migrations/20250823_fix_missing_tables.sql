-- Fix missing tables/views for scout-databank deployment
-- This migration creates the required views that the frontend is expecting

-- 1. Create tenant_settings_api view (for multi-tenant configuration)
CREATE OR REPLACE VIEW public.tenant_settings_api AS
SELECT 
  'default'::text as tenant_id,
  'Scout Platform'::text as tenant_name,
  jsonb_build_object(
    'features', jsonb_build_object(
      'ai_chat', true,
      'geographic_map', true,
      'comparative_analytics', true
    ),
    'branding', jsonb_build_object(
      'primary_color', '#FFD700',
      'logo_url', '/logo.png'
    ),
    'api_limits', jsonb_build_object(
      'requests_per_minute', 60,
      'max_export_rows', 10000
    )
  ) as settings,
  now() as created_at,
  now() as updated_at;

-- Grant access to anon role
GRANT SELECT ON public.tenant_settings_api TO anon;

-- 2. Create gold_product_performance view
CREATE OR REPLACE VIEW public.gold_product_performance AS
SELECT 
  p.id,
  p.product_name,
  p.brand_id,
  b.brand_name,
  p.category_id,
  c.category_name,
  COALESCE(ps.revenue, 0) as revenue,
  COALESCE(ps.units_sold, 0) as units_sold,
  COALESCE(ps.transaction_count, 0) as transaction_count,
  COALESCE(ps.avg_price, 0) as avg_price,
  ps.last_sale_date,
  now() as last_updated
FROM public.products p
LEFT JOIN public.brands b ON p.brand_id = b.id
LEFT JOIN public.categories c ON p.category_id = c.id
LEFT JOIN LATERAL (
  SELECT 
    SUM(ti.total_amount) as revenue,
    SUM(ti.quantity) as units_sold,
    COUNT(DISTINCT ti.transaction_id) as transaction_count,
    AVG(ti.unit_price) as avg_price,
    MAX(t.transaction_date) as last_sale_date
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE ti.product_id = p.id
    AND t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
) ps ON true
WHERE p.is_active = true
ORDER BY revenue DESC;

-- Grant access to anon role
GRANT SELECT ON public.gold_product_performance TO anon;

-- 3. Create mv_daily_metrics materialized view if not exists
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_daily_metrics AS
SELECT 
  DATE(t.transaction_date) as date,
  t.brand_id,
  b.brand_name,
  COUNT(DISTINCT t.id) as transaction_count,
  SUM(t.total_amount) as revenue,
  AVG(t.total_amount) as avg_basket_size,
  AVG(
    EXTRACT(EPOCH FROM (t.updated_at - t.created_at))/60
  ) as avg_duration,
  COUNT(DISTINCT t.consumer_id) as unique_consumers
FROM public.transactions t
LEFT JOIN public.brands b ON t.brand_id = b.id
WHERE t.status = 'completed'
GROUP BY DATE(t.transaction_date), t.brand_id, b.brand_name;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_mv_daily_metrics_date ON public.mv_daily_metrics(date);
CREATE INDEX IF NOT EXISTS idx_mv_daily_metrics_brand ON public.mv_daily_metrics(brand_id);

-- Grant access
GRANT SELECT ON public.mv_daily_metrics TO anon;

-- 4. Create mv_regional_performance view
CREATE OR REPLACE VIEW public.mv_regional_performance AS
SELECT 
  r.id as region_id,
  r.name as region_name,
  r.psgc_code as psgc,
  COUNT(DISTINCT t.id) as transactions,
  SUM(t.total_amount) as revenue,
  COUNT(DISTINCT t.consumer_id) as unique_consumers,
  AVG(t.total_amount) as avg_basket_size
FROM public.regions r
LEFT JOIN public.stores s ON s.region_id = r.id
LEFT JOIN public.transactions t ON t.store_id = s.id 
  AND t.status = 'completed'
  AND t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY r.id, r.name, r.psgc_code;

-- Grant access
GRANT SELECT ON public.mv_regional_performance TO anon;

-- 5. Create get_product_mix function
CREATE OR REPLACE FUNCTION public.get_product_mix(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  brand_filter uuid DEFAULT NULL
)
RETURNS TABLE (
  category_name text,
  product_count bigint,
  revenue numeric,
  units_sold bigint,
  percentage numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH product_stats AS (
    SELECT 
      c.category_name,
      COUNT(DISTINCT ti.product_id) as product_count,
      SUM(ti.total_amount) as revenue,
      SUM(ti.quantity) as units_sold
    FROM public.transaction_items ti
    JOIN public.transactions t ON ti.transaction_id = t.id
    JOIN public.products p ON ti.product_id = p.id
    JOIN public.categories c ON p.category_id = c.id
    WHERE t.transaction_date BETWEEN start_date AND end_date
      AND t.status = 'completed'
      AND (brand_filter IS NULL OR t.brand_id = brand_filter)
    GROUP BY c.category_name
  ),
  total_revenue AS (
    SELECT SUM(revenue) as total FROM product_stats
  )
  SELECT 
    ps.category_name,
    ps.product_count,
    ps.revenue,
    ps.units_sold,
    ROUND((ps.revenue / tr.total * 100)::numeric, 2) as percentage
  FROM product_stats ps
  CROSS JOIN total_revenue tr
  ORDER BY ps.revenue DESC;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_product_mix TO anon;

-- 6. Create consumer_profiles table if not exists
CREATE TABLE IF NOT EXISTS public.consumer_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consumer_id uuid REFERENCES public.consumers(id),
  profile_type text,
  preferences jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Grant access
GRANT SELECT ON public.consumer_profiles TO anon;

-- 7. Add missing columns to transactions if they don't exist
DO $$ 
BEGIN
  -- Add request_method if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'transactions' 
    AND column_name = 'request_method'
  ) THEN
    ALTER TABLE public.transactions 
    ADD COLUMN request_method text DEFAULT 'online';
  END IF;

  -- Add payment_method if not exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'transactions' 
    AND column_name = 'payment_method'
  ) THEN
    ALTER TABLE public.transactions 
    ADD COLUMN payment_method text DEFAULT 'cash';
  END IF;
END $$;

-- 8. Refresh materialized view
REFRESH MATERIALIZED VIEW public.mv_daily_metrics;

-- Add RLS policies for security
ALTER TABLE public.tenant_settings_api ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gold_product_performance ENABLE ROW LEVEL SECURITY;

-- Create policies that allow read access
CREATE POLICY "Allow public read access" ON public.tenant_settings_api
  FOR SELECT USING (true);

CREATE POLICY "Allow public read access" ON public.gold_product_performance
  FOR SELECT USING (true);