-- Migration: 025_gold_analytics_views.sql
-- Description: Create comprehensive Gold layer views for Scout Analytics Dashboard
-- These views provide ready-to-use data for the submodule DAL service

-- Drop existing views if they exist
DROP VIEW IF EXISTS scout.gold_dashboard_kpis CASCADE;
DROP VIEW IF EXISTS scout.gold_product_performance CASCADE;
DROP VIEW IF EXISTS scout.gold_campaign_effectiveness CASCADE;
DROP VIEW IF EXISTS scout.gold_customer_segments CASCADE;
DROP VIEW IF EXISTS scout.gold_store_performance CASCADE;
DROP VIEW IF EXISTS scout.gold_sales_trends CASCADE;
DROP VIEW IF EXISTS scout.gold_inventory_analysis CASCADE;
DROP VIEW IF EXISTS scout.gold_category_insights CASCADE;
DROP VIEW IF EXISTS scout.gold_geographic_summary CASCADE;
DROP VIEW IF EXISTS scout.gold_time_series_metrics CASCADE;

-- =====================================================
-- 1. Dashboard KPIs View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_dashboard_kpis AS
WITH current_period AS (
  SELECT 
    COUNT(DISTINCT f.transaction_id) as transaction_count,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    SUM(f.sales_amount) as total_revenue,
    SUM(f.quantity) as total_units_sold,
    AVG(f.sales_amount) as avg_transaction_value,
    COUNT(DISTINCT f.product_id) as products_sold,
    COUNT(DISTINCT f.store_id) as active_stores
  FROM scout.fact_sales f
  WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
),
previous_period AS (
  SELECT 
    SUM(f.sales_amount) as total_revenue,
    COUNT(DISTINCT f.customer_id) as unique_customers
  FROM scout.fact_sales f
  WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '60 days'
    AND f.transaction_date < CURRENT_DATE - INTERVAL '30 days'
),
inventory_metrics AS (
  SELECT 
    SUM(current_stock) as total_inventory_units,
    SUM(current_stock * unit_cost) as total_inventory_value,
    COUNT(DISTINCT product_id) as total_skus,
    COUNT(CASE WHEN current_stock <= reorder_point THEN 1 END) as low_stock_items
  FROM scout.fact_inventory
  WHERE snapshot_date = CURRENT_DATE
)
SELECT 
  cp.transaction_count,
  cp.unique_customers,
  cp.total_revenue,
  cp.total_units_sold,
  cp.avg_transaction_value,
  cp.products_sold,
  cp.active_stores,
  -- Growth metrics
  CASE 
    WHEN pp.total_revenue > 0 
    THEN ((cp.total_revenue - pp.total_revenue) / pp.total_revenue * 100)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_growth_pct,
  CASE 
    WHEN pp.unique_customers > 0 
    THEN ((cp.unique_customers - pp.unique_customers) / pp.unique_customers * 100)::DECIMAL(10,2)
    ELSE 0 
  END as customer_growth_pct,
  -- Inventory metrics
  im.total_inventory_units,
  im.total_inventory_value,
  im.total_skus,
  im.low_stock_items,
  -- Calculated metrics
  CASE 
    WHEN cp.unique_customers > 0 
    THEN (cp.total_revenue / cp.unique_customers)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_per_customer,
  CASE 
    WHEN cp.transaction_count > 0 
    THEN (cp.total_units_sold::DECIMAL / cp.transaction_count)::DECIMAL(10,2)
    ELSE 0 
  END as units_per_transaction,
  CURRENT_TIMESTAMP as last_updated
FROM current_period cp
CROSS JOIN previous_period pp
CROSS JOIN inventory_metrics im;

-- =====================================================
-- 2. Product Performance View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_product_performance AS
WITH product_sales AS (
  SELECT 
    p.product_id,
    p.product_name,
    p.brand,
    c.category_name,
    c.department,
    SUM(f.quantity) as units_sold,
    SUM(f.sales_amount) as revenue,
    SUM(f.discount_amount) as total_discount,
    COUNT(DISTINCT f.transaction_id) as transaction_count,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    COUNT(DISTINCT f.store_id) as stores_selling
  FROM scout.fact_sales f
  JOIN scout.dim_products p ON f.product_id = p.product_id
  JOIN scout.dim_categories c ON p.category_id = c.category_id
  WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY p.product_id, p.product_name, p.brand, c.category_name, c.department
),
inventory_status AS (
  SELECT 
    product_id,
    SUM(current_stock) as current_stock,
    SUM(current_stock * unit_cost) as inventory_value,
    AVG(stock_turnover_rate) as avg_turnover_rate
  FROM scout.fact_inventory
  WHERE snapshot_date = CURRENT_DATE
  GROUP BY product_id
),
product_ranking AS (
  SELECT 
    product_id,
    ROW_NUMBER() OVER (ORDER BY revenue DESC) as revenue_rank,
    ROW_NUMBER() OVER (ORDER BY units_sold DESC) as volume_rank,
    NTILE(4) OVER (ORDER BY revenue DESC) as revenue_quartile
  FROM product_sales
)
SELECT 
  ps.product_id,
  ps.product_name,
  ps.brand,
  ps.category_name,
  ps.department,
  ps.units_sold,
  ps.revenue,
  ps.total_discount,
  ps.transaction_count,
  ps.unique_customers,
  ps.stores_selling,
  -- Inventory metrics
  COALESCE(inv.current_stock, 0) as current_stock,
  COALESCE(inv.inventory_value, 0) as inventory_value,
  COALESCE(inv.avg_turnover_rate, 0) as turnover_rate,
  -- Performance metrics
  (ps.revenue / NULLIF(ps.units_sold, 0))::DECIMAL(10,2) as avg_selling_price,
  (ps.total_discount / NULLIF(ps.revenue + ps.total_discount, 0) * 100)::DECIMAL(5,2) as discount_rate,
  (ps.revenue / NULLIF(ps.transaction_count, 0))::DECIMAL(10,2) as revenue_per_transaction,
  -- Rankings
  pr.revenue_rank,
  pr.volume_rank,
  pr.revenue_quartile,
  -- Stock metrics
  CASE 
    WHEN ps.units_sold > 0 AND inv.current_stock > 0
    THEN (inv.current_stock::DECIMAL / (ps.units_sold / 30))::INTEGER
    ELSE 0
  END as days_of_supply,
  CURRENT_TIMESTAMP as last_updated
FROM product_sales ps
LEFT JOIN inventory_status inv ON ps.product_id = inv.product_id
LEFT JOIN product_ranking pr ON ps.product_id = pr.product_id
ORDER BY ps.revenue DESC;

-- =====================================================
-- 3. Campaign Effectiveness View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_campaign_effectiveness AS
WITH campaign_metrics AS (
  SELECT 
    c.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.start_date,
    c.end_date,
    c.budget,
    c.target_audience,
    COUNT(DISTINCT f.transaction_id) as transactions,
    COUNT(DISTINCT f.customer_id) as customers_reached,
    SUM(f.quantity) as units_sold,
    SUM(f.sales_amount) as revenue_generated,
    SUM(f.discount_amount) as discounts_given
  FROM scout.fact_campaigns f
  JOIN scout.dim_campaigns c ON f.campaign_id = c.campaign_id
  GROUP BY c.campaign_id, c.campaign_name, c.campaign_type, 
           c.start_date, c.end_date, c.budget, c.target_audience
),
campaign_products AS (
  SELECT 
    fc.campaign_id,
    COUNT(DISTINCT fc.product_id) as products_promoted,
    STRING_AGG(DISTINCT p.category_name, ', ' ORDER BY p.category_name) as categories_promoted
  FROM scout.fact_campaigns fc
  JOIN (
    SELECT DISTINCT p.product_id, c.category_name
    FROM scout.dim_products p
    JOIN scout.dim_categories c ON p.category_id = c.category_id
  ) p ON fc.product_id = p.product_id
  GROUP BY fc.campaign_id
)
SELECT 
  cm.campaign_id,
  cm.campaign_name,
  cm.campaign_type,
  cm.start_date,
  cm.end_date,
  cm.budget,
  cm.target_audience,
  cm.transactions,
  cm.customers_reached,
  cm.units_sold,
  cm.revenue_generated,
  cm.discounts_given,
  cp.products_promoted,
  cp.categories_promoted,
  -- ROI metrics
  (cm.revenue_generated - cm.discounts_given) as net_revenue,
  CASE 
    WHEN cm.budget > 0 
    THEN ((cm.revenue_generated - cm.discounts_given - cm.budget) / cm.budget * 100)::DECIMAL(10,2)
    ELSE 0 
  END as roi_percentage,
  CASE 
    WHEN cm.budget > 0 
    THEN (cm.revenue_generated / cm.budget)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_to_spend_ratio,
  -- Efficiency metrics
  CASE 
    WHEN cm.customers_reached > 0 
    THEN (cm.budget / cm.customers_reached)::DECIMAL(10,2)
    ELSE 0 
  END as cost_per_customer,
  CASE 
    WHEN cm.transactions > 0 
    THEN (cm.budget / cm.transactions)::DECIMAL(10,2)
    ELSE 0 
  END as cost_per_transaction,
  CASE 
    WHEN cm.customers_reached > 0 
    THEN (cm.revenue_generated / cm.customers_reached)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_per_customer,
  -- Campaign status
  CASE 
    WHEN CURRENT_DATE < cm.start_date THEN 'Scheduled'
    WHEN CURRENT_DATE BETWEEN cm.start_date AND cm.end_date THEN 'Active'
    ELSE 'Completed'
  END as campaign_status,
  CURRENT_TIMESTAMP as last_updated
FROM campaign_metrics cm
LEFT JOIN campaign_products cp ON cm.campaign_id = cp.campaign_id
ORDER BY cm.revenue_generated DESC;

-- =====================================================
-- 4. Customer Segments View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_customer_segments AS
WITH customer_metrics AS (
  SELECT 
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.customer_type,
    c.registration_date,
    COUNT(DISTINCT f.transaction_id) as transaction_count,
    SUM(f.sales_amount) as total_spent,
    SUM(f.quantity) as total_units,
    COUNT(DISTINCT f.product_id) as unique_products,
    COUNT(DISTINCT f.store_id) as stores_visited,
    COUNT(DISTINCT DATE_TRUNC('month', f.transaction_date)) as active_months,
    MIN(f.transaction_date) as first_purchase,
    MAX(f.transaction_date) as last_purchase,
    AVG(f.sales_amount) as avg_transaction_value
  FROM scout.dim_customers c
  LEFT JOIN scout.fact_sales f ON c.customer_id = f.customer_id
  GROUP BY c.customer_id, c.customer_name, c.customer_segment, 
           c.customer_type, c.registration_date
),
customer_recency AS (
  SELECT 
    customer_id,
    CASE 
      WHEN last_purchase >= CURRENT_DATE - INTERVAL '30 days' THEN 'Active'
      WHEN last_purchase >= CURRENT_DATE - INTERVAL '90 days' THEN 'At Risk'
      WHEN last_purchase >= CURRENT_DATE - INTERVAL '180 days' THEN 'Dormant'
      ELSE 'Lost'
    END as recency_status,
    CURRENT_DATE - last_purchase::DATE as days_since_last_purchase
  FROM customer_metrics
  WHERE last_purchase IS NOT NULL
),
segment_benchmarks AS (
  SELECT 
    customer_segment,
    AVG(total_spent) as segment_avg_spent,
    AVG(transaction_count) as segment_avg_transactions
  FROM customer_metrics
  GROUP BY customer_segment
)
SELECT 
  cm.customer_id,
  cm.customer_name,
  cm.customer_segment,
  cm.customer_type,
  cm.registration_date,
  cm.transaction_count,
  cm.total_spent,
  cm.total_units,
  cm.unique_products,
  cm.stores_visited,
  cm.active_months,
  cm.first_purchase,
  cm.last_purchase,
  cm.avg_transaction_value,
  cr.recency_status,
  cr.days_since_last_purchase,
  -- Lifetime value metrics
  CASE 
    WHEN cm.active_months > 0 
    THEN (cm.total_spent / cm.active_months)::DECIMAL(10,2)
    ELSE 0 
  END as monthly_spend_avg,
  CASE 
    WHEN cm.transaction_count > 0 
    THEN (cm.active_months::DECIMAL / cm.transaction_count * 30)::INTEGER
    ELSE 0 
  END as avg_days_between_purchases,
  -- Segment comparison
  (cm.total_spent / NULLIF(sb.segment_avg_spent, 0))::DECIMAL(10,2) as spend_vs_segment_avg,
  (cm.transaction_count / NULLIF(sb.segment_avg_transactions, 0))::DECIMAL(10,2) as transactions_vs_segment_avg,
  -- Customer scoring
  CASE 
    WHEN cm.total_spent > sb.segment_avg_spent * 2 AND cm.transaction_count > 10 THEN 'VIP'
    WHEN cm.total_spent > sb.segment_avg_spent AND cr.recency_status = 'Active' THEN 'High Value'
    WHEN cr.recency_status IN ('At Risk', 'Dormant') THEN 'Reactivation Target'
    ELSE 'Standard'
  END as customer_tier,
  CURRENT_TIMESTAMP as last_updated
FROM customer_metrics cm
LEFT JOIN customer_recency cr ON cm.customer_id = cr.customer_id
LEFT JOIN segment_benchmarks sb ON cm.customer_segment = sb.customer_segment
ORDER BY cm.total_spent DESC;

-- =====================================================
-- 5. Store Performance View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_store_performance AS
WITH store_sales AS (
  SELECT 
    s.store_id,
    s.store_name,
    s.store_type,
    s.city,
    s.region,
    s.store_size,
    COUNT(DISTINCT f.transaction_id) as transaction_count,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    COUNT(DISTINCT f.product_id) as unique_products,
    SUM(f.sales_amount) as total_revenue,
    SUM(f.quantity) as units_sold,
    SUM(f.discount_amount) as total_discounts,
    COUNT(DISTINCT DATE(f.transaction_date)) as days_active
  FROM scout.dim_stores s
  LEFT JOIN scout.fact_sales f ON s.store_id = f.store_id
    AND f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY s.store_id, s.store_name, s.store_type, s.city, s.region, s.store_size
),
store_inventory AS (
  SELECT 
    store_id,
    COUNT(DISTINCT product_id) as products_stocked,
    SUM(current_stock) as total_inventory,
    SUM(current_stock * unit_cost) as inventory_value
  FROM scout.fact_inventory
  WHERE snapshot_date = CURRENT_DATE
  GROUP BY store_id
),
regional_benchmarks AS (
  SELECT 
    s.region,
    AVG(ss.total_revenue) as region_avg_revenue,
    AVG(ss.transaction_count) as region_avg_transactions
  FROM scout.dim_stores s
  JOIN store_sales ss ON s.store_id = ss.store_id
  GROUP BY s.region
)
SELECT 
  ss.store_id,
  ss.store_name,
  ss.store_type,
  ss.city,
  ss.region,
  ss.store_size,
  ss.transaction_count,
  ss.unique_customers,
  ss.unique_products as products_sold,
  ss.total_revenue,
  ss.units_sold,
  ss.total_discounts,
  ss.days_active,
  -- Inventory metrics
  COALESCE(si.products_stocked, 0) as products_stocked,
  COALESCE(si.total_inventory, 0) as total_inventory,
  COALESCE(si.inventory_value, 0) as inventory_value,
  -- Performance metrics
  CASE 
    WHEN ss.days_active > 0 
    THEN (ss.total_revenue / ss.days_active)::DECIMAL(10,2)
    ELSE 0 
  END as daily_revenue_avg,
  CASE 
    WHEN ss.transaction_count > 0 
    THEN (ss.total_revenue / ss.transaction_count)::DECIMAL(10,2)
    ELSE 0 
  END as avg_transaction_value,
  CASE 
    WHEN ss.store_size > 0 
    THEN (ss.total_revenue / ss.store_size)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_per_sqft,
  -- Regional comparison
  CASE 
    WHEN rb.region_avg_revenue > 0 
    THEN (ss.total_revenue / rb.region_avg_revenue * 100)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_vs_region_avg,
  -- Inventory efficiency
  CASE 
    WHEN si.inventory_value > 0 
    THEN (ss.total_revenue / si.inventory_value)::DECIMAL(10,2)
    ELSE 0 
  END as inventory_turnover,
  CURRENT_TIMESTAMP as last_updated
FROM store_sales ss
LEFT JOIN store_inventory si ON ss.store_id = si.store_id
LEFT JOIN regional_benchmarks rb ON ss.region = rb.region
ORDER BY ss.total_revenue DESC;

-- =====================================================
-- 6. Sales Trends View (Time Series)
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_sales_trends AS
WITH daily_sales AS (
  SELECT 
    DATE(transaction_date) as sale_date,
    COUNT(DISTINCT transaction_id) as transactions,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(sales_amount) as revenue,
    SUM(quantity) as units_sold,
    SUM(discount_amount) as discounts,
    COUNT(DISTINCT store_id) as active_stores,
    COUNT(DISTINCT product_id) as products_sold
  FROM scout.fact_sales
  WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY DATE(transaction_date)
),
moving_averages AS (
  SELECT 
    sale_date,
    transactions,
    unique_customers,
    revenue,
    units_sold,
    discounts,
    active_stores,
    products_sold,
    -- 7-day moving averages
    AVG(revenue) OVER (
      ORDER BY sale_date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::DECIMAL(10,2) as revenue_7d_avg,
    AVG(transactions) OVER (
      ORDER BY sale_date 
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::DECIMAL(10,2) as transactions_7d_avg,
    -- 30-day moving averages
    AVG(revenue) OVER (
      ORDER BY sale_date 
      ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    )::DECIMAL(10,2) as revenue_30d_avg,
    -- Year over year comparison
    LAG(revenue, 365) OVER (ORDER BY sale_date) as revenue_last_year,
    LAG(transactions, 365) OVER (ORDER BY sale_date) as transactions_last_year
  FROM daily_sales
)
SELECT 
  sale_date,
  TO_CHAR(sale_date, 'Day') as day_of_week,
  EXTRACT(WEEK FROM sale_date) as week_number,
  EXTRACT(MONTH FROM sale_date) as month_number,
  TO_CHAR(sale_date, 'Month') as month_name,
  transactions,
  unique_customers,
  revenue,
  units_sold,
  discounts,
  active_stores,
  products_sold,
  revenue_7d_avg,
  transactions_7d_avg,
  revenue_30d_avg,
  -- Period over period changes
  revenue - LAG(revenue, 1) OVER (ORDER BY sale_date) as revenue_change_1d,
  revenue - LAG(revenue, 7) OVER (ORDER BY sale_date) as revenue_change_7d,
  -- YoY metrics
  revenue_last_year,
  CASE 
    WHEN revenue_last_year > 0 
    THEN ((revenue - revenue_last_year) / revenue_last_year * 100)::DECIMAL(10,2)
    ELSE 0 
  END as revenue_yoy_change_pct,
  transactions_last_year,
  CASE 
    WHEN transactions_last_year > 0 
    THEN ((transactions - transactions_last_year) / transactions_last_year * 100)::DECIMAL(10,2)
    ELSE 0 
  END as transactions_yoy_change_pct,
  -- Calculated metrics
  (revenue / NULLIF(transactions, 0))::DECIMAL(10,2) as avg_transaction_value,
  (units_sold / NULLIF(transactions, 0))::DECIMAL(10,2) as units_per_transaction,
  (discounts / NULLIF(revenue + discounts, 0) * 100)::DECIMAL(5,2) as discount_rate,
  CURRENT_TIMESTAMP as last_updated
FROM moving_averages
ORDER BY sale_date DESC;

-- =====================================================
-- 7. Inventory Analysis View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_inventory_analysis AS
WITH current_inventory AS (
  SELECT 
    i.product_id,
    p.product_name,
    p.brand,
    c.category_name,
    c.department,
    i.store_id,
    s.store_name,
    s.region,
    i.current_stock,
    i.unit_cost,
    i.reorder_point,
    i.reorder_quantity,
    i.current_stock * i.unit_cost as inventory_value,
    i.stock_turnover_rate
  FROM scout.fact_inventory i
  JOIN scout.dim_products p ON i.product_id = p.product_id
  JOIN scout.dim_categories c ON p.category_id = c.category_id
  JOIN scout.dim_stores s ON i.store_id = s.store_id
  WHERE i.snapshot_date = CURRENT_DATE
),
sales_velocity AS (
  SELECT 
    product_id,
    store_id,
    AVG(quantity) as avg_daily_sales,
    STDDEV(quantity) as sales_stddev
  FROM scout.fact_sales
  WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY product_id, store_id
)
SELECT 
  ci.product_id,
  ci.product_name,
  ci.brand,
  ci.category_name,
  ci.department,
  ci.store_id,
  ci.store_name,
  ci.region,
  ci.current_stock,
  ci.unit_cost,
  ci.reorder_point,
  ci.reorder_quantity,
  ci.inventory_value,
  ci.stock_turnover_rate,
  -- Sales velocity metrics
  COALESCE(sv.avg_daily_sales, 0) as avg_daily_sales,
  COALESCE(sv.sales_stddev, 0) as sales_volatility,
  -- Stock analysis
  CASE 
    WHEN ci.current_stock <= 0 THEN 'Out of Stock'
    WHEN ci.current_stock <= ci.reorder_point THEN 'Low Stock'
    WHEN ci.current_stock > ci.reorder_point * 3 THEN 'Overstock'
    ELSE 'Normal'
  END as stock_status,
  -- Days of supply
  CASE 
    WHEN sv.avg_daily_sales > 0 
    THEN (ci.current_stock / sv.avg_daily_sales)::INTEGER
    ELSE 999
  END as days_of_supply,
  -- Reorder recommendation
  CASE 
    WHEN ci.current_stock <= ci.reorder_point THEN 'Reorder Now'
    WHEN sv.avg_daily_sales > 0 AND 
         ci.current_stock <= ci.reorder_point + (sv.avg_daily_sales * 7) THEN 'Reorder Soon'
    ELSE 'No Action'
  END as reorder_recommendation,
  -- Financial metrics
  CASE 
    WHEN sv.avg_daily_sales > 0 
    THEN (ci.inventory_value / (sv.avg_daily_sales * ci.unit_cost))::DECIMAL(10,2)
    ELSE 0
  END as inventory_days_on_hand,
  CURRENT_TIMESTAMP as last_updated
FROM current_inventory ci
LEFT JOIN sales_velocity sv ON ci.product_id = sv.product_id 
                           AND ci.store_id = sv.store_id
ORDER BY ci.inventory_value DESC;

-- =====================================================
-- 8. Category Insights View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_category_insights AS
WITH category_sales AS (
  SELECT 
    c.category_id,
    c.category_name,
    c.department,
    COUNT(DISTINCT f.product_id) as products_sold,
    COUNT(DISTINCT f.transaction_id) as transactions,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    COUNT(DISTINCT f.store_id) as stores_selling,
    SUM(f.sales_amount) as revenue,
    SUM(f.quantity) as units_sold,
    SUM(f.discount_amount) as discounts_given
  FROM scout.fact_sales f
  JOIN scout.dim_products p ON f.product_id = p.product_id
  JOIN scout.dim_categories c ON p.category_id = c.category_id
  WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY c.category_id, c.category_name, c.department
),
category_inventory AS (
  SELECT 
    c.category_id,
    COUNT(DISTINCT i.product_id) as total_skus,
    SUM(i.current_stock) as total_inventory,
    SUM(i.current_stock * i.unit_cost) as inventory_value,
    AVG(i.stock_turnover_rate) as avg_turnover_rate
  FROM scout.fact_inventory i
  JOIN scout.dim_products p ON i.product_id = p.product_id
  JOIN scout.dim_categories c ON p.category_id = c.category_id
  WHERE i.snapshot_date = CURRENT_DATE
  GROUP BY c.category_id
),
department_totals AS (
  SELECT 
    department,
    SUM(revenue) as dept_total_revenue
  FROM category_sales
  GROUP BY department
)
SELECT 
  cs.category_id,
  cs.category_name,
  cs.department,
  cs.products_sold,
  cs.transactions,
  cs.unique_customers,
  cs.stores_selling,
  cs.revenue,
  cs.units_sold,
  cs.discounts_given,
  -- Inventory metrics
  ci.total_skus,
  ci.total_inventory,
  ci.inventory_value,
  ci.avg_turnover_rate,
  -- Performance metrics
  (cs.revenue / NULLIF(cs.units_sold, 0))::DECIMAL(10,2) as avg_price_per_unit,
  (cs.revenue / NULLIF(cs.transactions, 0))::DECIMAL(10,2) as avg_revenue_per_transaction,
  (cs.discounts_given / NULLIF(cs.revenue + cs.discounts_given, 0) * 100)::DECIMAL(5,2) as discount_rate,
  -- Market share
  (cs.revenue / NULLIF(dt.dept_total_revenue, 0) * 100)::DECIMAL(5,2) as dept_revenue_share,
  -- Ranking
  ROW_NUMBER() OVER (ORDER BY cs.revenue DESC) as revenue_rank,
  ROW_NUMBER() OVER (PARTITION BY cs.department ORDER BY cs.revenue DESC) as dept_revenue_rank,
  -- Growth potential
  CASE 
    WHEN ci.total_skus > cs.products_sold 
    THEN ((ci.total_skus - cs.products_sold)::DECIMAL / ci.total_skus * 100)::DECIMAL(5,2)
    ELSE 0 
  END as unsold_product_pct,
  CURRENT_TIMESTAMP as last_updated
FROM category_sales cs
LEFT JOIN category_inventory ci ON cs.category_id = ci.category_id
LEFT JOIN department_totals dt ON cs.department = dt.department
ORDER BY cs.revenue DESC;

-- =====================================================
-- 9. Geographic Summary View
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_geographic_summary AS
WITH regional_sales AS (
  SELECT 
    s.region,
    s.city,
    COUNT(DISTINCT s.store_id) as store_count,
    COUNT(DISTINCT f.transaction_id) as total_transactions,
    COUNT(DISTINCT f.customer_id) as unique_customers,
    SUM(f.sales_amount) as total_revenue,
    SUM(f.quantity) as units_sold,
    SUM(f.discount_amount) as total_discounts,
    COUNT(DISTINCT f.product_id) as unique_products_sold
  FROM scout.dim_stores s
  LEFT JOIN scout.fact_sales f ON s.store_id = f.store_id
    AND f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY s.region, s.city
),
regional_inventory AS (
  SELECT 
    s.region,
    s.city,
    SUM(i.current_stock) as total_inventory,
    SUM(i.current_stock * i.unit_cost) as inventory_value,
    COUNT(DISTINCT i.product_id) as products_stocked
  FROM scout.dim_stores s
  JOIN scout.fact_inventory i ON s.store_id = i.store_id
  WHERE i.snapshot_date = CURRENT_DATE
  GROUP BY s.region, s.city
),
national_totals AS (
  SELECT 
    SUM(total_revenue) as national_revenue,
    SUM(total_transactions) as national_transactions
  FROM regional_sales
)
SELECT 
  rs.region,
  rs.city,
  rs.store_count,
  rs.total_transactions,
  rs.unique_customers,
  rs.total_revenue,
  rs.units_sold,
  rs.total_discounts,
  rs.unique_products_sold,
  -- Inventory metrics
  COALESCE(ri.total_inventory, 0) as total_inventory,
  COALESCE(ri.inventory_value, 0) as inventory_value,
  COALESCE(ri.products_stocked, 0) as products_stocked,
  -- Performance metrics
  (rs.total_revenue / NULLIF(rs.store_count, 0))::DECIMAL(10,2) as revenue_per_store,
  (rs.total_revenue / NULLIF(rs.total_transactions, 0))::DECIMAL(10,2) as avg_transaction_value,
  (rs.total_revenue / NULLIF(rs.unique_customers, 0))::DECIMAL(10,2) as revenue_per_customer,
  -- Market share
  (rs.total_revenue / NULLIF(nt.national_revenue, 0) * 100)::DECIMAL(5,2) as revenue_market_share,
  (rs.total_transactions / NULLIF(nt.national_transactions, 0) * 100)::DECIMAL(5,2) as transaction_market_share,
  -- Efficiency metrics
  CASE 
    WHEN ri.inventory_value > 0 
    THEN (rs.total_revenue / ri.inventory_value)::DECIMAL(10,2)
    ELSE 0 
  END as inventory_turnover,
  -- Rankings
  ROW_NUMBER() OVER (ORDER BY rs.total_revenue DESC) as revenue_rank,
  ROW_NUMBER() OVER (PARTITION BY rs.region ORDER BY rs.total_revenue DESC) as regional_rank,
  CURRENT_TIMESTAMP as last_updated
FROM regional_sales rs
LEFT JOIN regional_inventory ri ON rs.region = ri.region AND rs.city = ri.city
CROSS JOIN national_totals nt
ORDER BY rs.total_revenue DESC;

-- =====================================================
-- 10. Time Series Metrics View (Hourly/Daily patterns)
-- =====================================================
CREATE OR REPLACE VIEW scout.gold_time_series_metrics AS
WITH hourly_patterns AS (
  SELECT 
    EXTRACT(HOUR FROM transaction_date) as hour_of_day,
    TO_CHAR(transaction_date, 'Day') as day_of_week,
    COUNT(transaction_id) as transactions,
    SUM(sales_amount) as revenue,
    SUM(quantity) as units_sold,
    COUNT(DISTINCT customer_id) as unique_customers,
    AVG(sales_amount) as avg_transaction_value
  FROM scout.fact_sales
  WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY EXTRACT(HOUR FROM transaction_date), TO_CHAR(transaction_date, 'Day')
),
daily_patterns AS (
  SELECT 
    EXTRACT(DOW FROM transaction_date) as day_of_week_num,
    TO_CHAR(transaction_date, 'Day') as day_name,
    COUNT(transaction_id) as daily_transactions,
    SUM(sales_amount) as daily_revenue,
    AVG(sales_amount) as daily_avg_transaction
  FROM scout.fact_sales
  WHERE transaction_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY EXTRACT(DOW FROM transaction_date), TO_CHAR(transaction_date, 'Day')
),
peak_hours AS (
  SELECT 
    hour_of_day,
    SUM(transactions) as total_transactions,
    SUM(revenue) as total_revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(revenue) DESC) as revenue_rank
  FROM hourly_patterns
  GROUP BY hour_of_day
)
SELECT 
  hp.hour_of_day,
  hp.day_of_week,
  hp.transactions,
  hp.revenue,
  hp.units_sold,
  hp.unique_customers,
  hp.avg_transaction_value,
  -- Peak analysis
  ph.revenue_rank as hourly_revenue_rank,
  CASE 
    WHEN ph.revenue_rank <= 3 THEN 'Peak Hour'
    WHEN ph.revenue_rank >= 20 THEN 'Off-Peak Hour'
    ELSE 'Normal Hour'
  END as hour_classification,
  -- Day patterns
  dp.daily_transactions,
  dp.daily_revenue,
  dp.daily_avg_transaction,
  -- Comparative metrics
  (hp.revenue / NULLIF(ph.total_revenue, 0) * 100)::DECIMAL(5,2) as hour_revenue_share,
  CURRENT_TIMESTAMP as last_updated
FROM hourly_patterns hp
LEFT JOIN peak_hours ph ON hp.hour_of_day = ph.hour_of_day
LEFT JOIN daily_patterns dp ON TRIM(hp.day_of_week) = TRIM(dp.day_name)
ORDER BY hp.hour_of_day, 
         CASE TRIM(hp.day_of_week)
           WHEN 'Monday' THEN 1
           WHEN 'Tuesday' THEN 2
           WHEN 'Wednesday' THEN 3
           WHEN 'Thursday' THEN 4
           WHEN 'Friday' THEN 5
           WHEN 'Saturday' THEN 6
           WHEN 'Sunday' THEN 7
         END;

-- =====================================================
-- Create Indexes for Performance
-- =====================================================
-- These views will benefit from these indexes on the base tables
CREATE INDEX IF NOT EXISTS idx_fact_sales_date ON scout.fact_sales(transaction_date);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product ON scout.fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_customer ON scout.fact_sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_store ON scout.fact_sales(store_id);
CREATE INDEX IF NOT EXISTS idx_fact_inventory_snapshot ON scout.fact_inventory(snapshot_date);
CREATE INDEX IF NOT EXISTS idx_fact_campaigns_campaign ON scout.fact_campaigns(campaign_id);

-- Grant appropriate permissions
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon;

-- Add comments for documentation
COMMENT ON VIEW scout.gold_dashboard_kpis IS 'Executive dashboard KPIs with growth metrics and inventory status';
COMMENT ON VIEW scout.gold_product_performance IS 'Product-level performance metrics with rankings and inventory status';
COMMENT ON VIEW scout.gold_campaign_effectiveness IS 'Marketing campaign ROI and effectiveness analysis';
COMMENT ON VIEW scout.gold_customer_segments IS 'Customer segmentation with lifetime value and tier classification';
COMMENT ON VIEW scout.gold_store_performance IS 'Store-level performance metrics with regional comparisons';
COMMENT ON VIEW scout.gold_sales_trends IS 'Time series sales data with moving averages and YoY comparisons';
COMMENT ON VIEW scout.gold_inventory_analysis IS 'Inventory status with reorder recommendations and turnover metrics';
COMMENT ON VIEW scout.gold_category_insights IS 'Category performance with market share and growth potential';
COMMENT ON VIEW scout.gold_geographic_summary IS 'Regional and city-level performance aggregations';
COMMENT ON VIEW scout.gold_time_series_metrics IS 'Hourly and daily sales patterns for operational insights';