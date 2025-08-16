-- Gold layer views for geographic choropleth visualizations
-- Combines transaction metrics with spatial boundaries

BEGIN;

-- Gold metrics by region (ADM1) with daily aggregation
CREATE OR REPLACE VIEW scout.gold_region_daily AS
SELECT
  scout.norm_region(COALESCE(s.region, d.region)) AS region_key,
  DATE_TRUNC('day', s.ts) AS day,
  COUNT(*) AS txn_count,
  COUNT(DISTINCT s.store_id) AS active_stores,
  COUNT(DISTINCT CASE WHEN s.customer_type = 'new' THEN s.id END) AS new_customers,
  SUM(s.peso_value)::NUMERIC(14,2) AS peso_total,
  AVG(s.peso_value)::NUMERIC(10,2) AS avg_transaction_value,
  SUM(s.units_per_transaction) AS total_units,
  AVG(s.basket_size)::NUMERIC(5,2) AS avg_basket_size,
  SUM(CASE WHEN s.time_of_day = 'morning' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS morning_sales,
  SUM(CASE WHEN s.time_of_day = 'afternoon' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS afternoon_sales,
  SUM(CASE WHEN s.time_of_day = 'evening' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS evening_sales,
  SUM(CASE WHEN s.time_of_day = 'night' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS night_sales,
  COUNT(CASE WHEN s.campaign_influenced THEN 1 END) AS campaign_influenced_txns,
  AVG(s.handshake_score)::NUMERIC(3,2) AS avg_handshake_score
FROM scout.silver_transactions s
LEFT JOIN scout.dim_store d ON d.store_id = s.store_id
GROUP BY 1, 2;

-- Gold metrics by province (ADM2) with daily aggregation
CREATE OR REPLACE VIEW scout.gold_province_daily AS
SELECT
  COALESCE(d.province_psgc, p.province_psgc) AS province_psgc,
  DATE_TRUNC('day', s.ts) AS day,
  COUNT(*) AS txn_count,
  COUNT(DISTINCT s.store_id) AS active_stores,
  SUM(s.peso_value)::NUMERIC(14,2) AS peso_total,
  AVG(s.peso_value)::NUMERIC(10,2) AS avg_transaction_value,
  SUM(s.units_per_transaction) AS total_units,
  AVG(s.basket_size)::NUMERIC(5,2) AS avg_basket_size
FROM scout.silver_transactions s
LEFT JOIN scout.dim_store d ON d.store_id = s.store_id
LEFT JOIN scout.geo_adm2_province p ON UPPER(p.province_name) = UPPER(s.province)
WHERE COALESCE(d.province_psgc, p.province_psgc) IS NOT NULL
GROUP BY 1, 2;

-- Gold metrics by city/municipality (ADM3) with daily aggregation
CREATE OR REPLACE VIEW scout.gold_citymun_daily AS
SELECT
  COALESCE(d.citymun_psgc, scout.norm_citymun(s.city, s.province)) AS citymun_psgc,
  DATE_TRUNC('day', s.ts) AS day,
  COUNT(*) AS txn_count,
  COUNT(DISTINCT s.store_id) AS active_stores,
  SUM(s.peso_value)::NUMERIC(14,2) AS peso_total,
  AVG(s.peso_value)::NUMERIC(10,2) AS avg_transaction_value,
  SUM(s.units_per_transaction) AS total_units,
  AVG(s.basket_size)::NUMERIC(5,2) AS avg_basket_size,
  -- Product category breakdowns
  SUM(CASE WHEN s.product_category = 'beverages' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS beverages_sales,
  SUM(CASE WHEN s.product_category = 'snacks' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS snacks_sales,
  SUM(CASE WHEN s.product_category = 'personal_care' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS personal_care_sales,
  SUM(CASE WHEN s.product_category = 'household' THEN s.peso_value ELSE 0 END)::NUMERIC(14,2) AS household_sales
FROM scout.silver_transactions s
LEFT JOIN scout.dim_store d ON d.store_id = s.store_id
WHERE COALESCE(d.citymun_psgc, scout.norm_citymun(s.city, s.province)) IS NOT NULL
GROUP BY 1, 2;

-- Spatial views for choropleth (region level with generalized geometry)
CREATE OR REPLACE VIEW scout.gold_region_choropleth AS
SELECT
  g.region_key,
  g.region_name,
  g.region_psgc,
  COALESCE(gen.geom, g.geom) AS geom,  -- Use simplified geometry if available
  m.day,
  m.txn_count,
  m.active_stores,
  m.new_customers,
  m.peso_total,
  m.avg_transaction_value,
  m.total_units,
  m.avg_basket_size,
  m.morning_sales,
  m.afternoon_sales,
  m.evening_sales,
  m.night_sales,
  m.campaign_influenced_txns,
  m.avg_handshake_score,
  -- Calculated metrics
  CASE 
    WHEN m.txn_count > 0 THEN m.peso_total / m.txn_count 
    ELSE 0 
  END AS revenue_per_transaction,
  g.area_sqkm,
  g.population,
  CASE 
    WHEN g.population > 0 THEN m.peso_total / g.population 
    ELSE 0 
  END AS revenue_per_capita
FROM scout.geo_adm1_region g
LEFT JOIN scout.geo_adm1_region_gen gen ON g.region_key = gen.region_key
LEFT JOIN scout.gold_region_daily m ON g.region_key = m.region_key;

-- Spatial views for choropleth (province level)
CREATE OR REPLACE VIEW scout.gold_province_choropleth AS
SELECT
  g.province_psgc,
  g.province_name,
  g.region_key,
  COALESCE(gen.geom, g.geom) AS geom,
  m.day,
  m.txn_count,
  m.active_stores,
  m.peso_total,
  m.avg_transaction_value,
  m.total_units,
  m.avg_basket_size,
  g.area_sqkm,
  g.population,
  CASE 
    WHEN g.population > 0 THEN m.peso_total / g.population 
    ELSE 0 
  END AS revenue_per_capita
FROM scout.geo_adm2_province g
LEFT JOIN scout.geo_adm2_province_gen gen ON g.province_psgc = gen.province_psgc
LEFT JOIN scout.gold_province_daily m ON g.province_psgc = m.province_psgc;

-- Spatial views for choropleth (city/municipality level)
CREATE OR REPLACE VIEW scout.gold_citymun_choropleth AS
SELECT
  g.citymun_psgc,
  g.citymun_name,
  g.province_psgc,
  g.region_key,
  COALESCE(gen.geom, g.geom) AS geom,  -- Use simplified geometry
  m.day,
  m.txn_count,
  m.active_stores,
  m.peso_total,
  m.avg_transaction_value,
  m.total_units,
  m.avg_basket_size,
  m.beverages_sales,
  m.snacks_sales,
  m.personal_care_sales,
  m.household_sales,
  g.area_sqkm,
  g.population,
  CASE 
    WHEN g.population > 0 THEN m.peso_total / g.population 
    ELSE 0 
  END AS revenue_per_capita,
  dc.income_class,
  dc.is_city
FROM scout.geo_adm3_citymun g
LEFT JOIN scout.geo_adm3_citymun_gen gen ON g.citymun_psgc = gen.citymun_psgc
LEFT JOIN scout.dim_geo_citymun dc ON g.citymun_psgc = dc.citymun_psgc
LEFT JOIN scout.gold_citymun_daily m ON g.citymun_psgc = m.citymun_psgc;

-- Weekly roll-up views for better performance on longer time ranges
CREATE OR REPLACE VIEW scout.gold_region_weekly AS
SELECT
  region_key,
  DATE_TRUNC('week', day) AS week,
  SUM(txn_count) AS txn_count,
  COUNT(DISTINCT day) AS active_days,
  SUM(peso_total) AS peso_total,
  AVG(avg_transaction_value) AS avg_transaction_value,
  SUM(total_units) AS total_units,
  AVG(avg_basket_size) AS avg_basket_size
FROM scout.gold_region_daily
GROUP BY 1, 2;

-- Monthly roll-up views
CREATE OR REPLACE VIEW scout.gold_region_monthly AS
SELECT
  region_key,
  DATE_TRUNC('month', day) AS month,
  SUM(txn_count) AS txn_count,
  COUNT(DISTINCT day) AS active_days,
  SUM(peso_total) AS peso_total,
  AVG(avg_transaction_value) AS avg_transaction_value,
  SUM(total_units) AS total_units,
  AVG(avg_basket_size) AS avg_basket_size,
  SUM(new_customers) AS new_customers,
  SUM(campaign_influenced_txns) AS campaign_influenced_txns
FROM scout.gold_region_daily
GROUP BY 1, 2;

-- Top performing stores by geography
CREATE OR REPLACE VIEW scout.gold_top_stores_by_region AS
SELECT
  d.region,
  d.store_id,
  d.store_name,
  d.city,
  d.province,
  COUNT(*) AS txn_count,
  SUM(s.peso_value) AS total_revenue,
  AVG(s.peso_value) AS avg_transaction_value,
  AVG(s.handshake_score) AS avg_handshake_score,
  RANK() OVER (PARTITION BY d.region ORDER BY SUM(s.peso_value) DESC) AS revenue_rank
FROM scout.silver_transactions s
JOIN scout.dim_store d ON s.store_id = d.store_id
WHERE s.ts >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY d.region, d.store_id, d.store_name, d.city, d.province;

-- Create indexes on frequently queried columns
CREATE INDEX IF NOT EXISTS idx_gold_region_daily_day ON scout.gold_region_daily(day);
CREATE INDEX IF NOT EXISTS idx_gold_province_daily_day ON scout.gold_province_daily(day);
CREATE INDEX IF NOT EXISTS idx_gold_citymun_daily_day ON scout.gold_citymun_daily(day);

COMMIT;