-- 028_sari_sari_functions.sql
-- Create database functions for Sari-Sari Optimizer components

-- Function for Tingi Economics Analysis
create or replace function scout.get_tingi_economics()
returns table(
  category text,
  brand text,
  pack_type text,
  transaction_count bigint,
  units_sold numeric,
  revenue numeric,
  avg_unit_price numeric,
  gross_profit numeric,
  margin_pct numeric
)
language sql
security definer
as $$
  WITH tingi_performance AS (
    SELECT 
      p.category,
      p.brand,
      CASE 
        WHEN p.product_name LIKE '%sachet%' OR p.unit_size < 50 THEN 'Tingi'
        WHEN p.unit_size BETWEEN 50 AND 200 THEN 'Regular' 
        ELSE 'Bulk'
      END as pack_type,
      COUNT(DISTINCT s.transaction_id) as transaction_count,
      SUM(s.quantity) as units_sold,
      SUM(s.total_amount) as revenue,
      AVG(s.total_amount/NULLIF(s.quantity,0)) as avg_unit_price,
      SUM(s.total_amount - (p.cost * s.quantity)) as gross_profit,
      AVG((s.total_amount - (p.cost * s.quantity))/NULLIF(s.total_amount,0) * 100) as margin_pct
    FROM scout.fact_transactions s
    JOIN scout.dim_products p ON s.product_id = p.product_id
    JOIN scout.fact_transaction_items ti ON s.transaction_id = ti.transaction_id
    WHERE s.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1,2,3
  )
  SELECT * FROM tingi_performance
  ORDER BY gross_profit DESC;
$$;

-- Function for Customer Credit Risk Analysis
create or replace function scout.get_credit_behavior()
returns table(
  customer_id text,
  customer_name text,
  credit_purchases bigint,
  total_credit numeric,
  avg_payment_days numeric,
  late_payments bigint,
  max_credit_amount numeric,
  credit_grade text,
  recommended_credit_limit numeric
)
language sql
security definer
as $$
  WITH credit_behavior AS (
    SELECT
      c.customer_id,
      c.customer_name,
      COUNT(CASE WHEN s.payment_method = 'Credit' THEN 1 END) as credit_purchases,
      SUM(CASE WHEN s.payment_method = 'Credit' THEN s.total_amount END) as total_credit,
      AVG(CASE WHEN s.payment_method = 'Credit' AND s.payment_date IS NOT NULL THEN 
        EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 END) as avg_payment_days,
      COUNT(CASE WHEN s.payment_date IS NOT NULL AND 
        EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 > 7 THEN 1 END) as late_payments,
      MAX(CASE WHEN s.payment_method = 'Credit' THEN s.total_amount END) as max_credit_amount,
      CASE
        WHEN AVG(CASE WHEN s.payment_method = 'Credit' AND s.payment_date IS NOT NULL THEN 
          EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 END) <= 3 THEN 'A-Prime'
        WHEN AVG(CASE WHEN s.payment_method = 'Credit' AND s.payment_date IS NOT NULL THEN 
          EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 END) <= 7 THEN 'B-Good'
        WHEN AVG(CASE WHEN s.payment_method = 'Credit' AND s.payment_date IS NOT NULL THEN 
          EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 END) <= 14 THEN 'C-Watch'
        ELSE 'D-Risk'
      END as credit_grade,
      CASE 
        WHEN COUNT(CASE WHEN s.payment_date IS NOT NULL AND 
          EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 > 7 THEN 1 END) = 0 
          THEN AVG(s.total_amount) * 3
        WHEN COUNT(CASE WHEN s.payment_date IS NOT NULL AND 
          EXTRACT(EPOCH FROM (s.payment_date - s.transaction_date))/86400 > 7 THEN 1 END) <= 2 
          THEN AVG(s.total_amount) * 1.5
        ELSE 0
      END as recommended_credit_limit
    FROM scout.dim_customers c
    LEFT JOIN scout.fact_transactions s ON c.customer_id = s.customer_id
    WHERE s.transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY 1,2
  )
  SELECT * FROM credit_behavior;
$$;

-- Function for Inventory Velocity Analysis
create or replace function scout.get_inventory_velocity()
returns table(
  product_id text,
  product_name text,
  category text,
  quantity_on_hand numeric,
  inventory_value numeric,
  units_sold_30d numeric,
  days_of_stock numeric,
  stock_status text,
  liquidation_strategy text
)
language sql
security definer
as $$
  WITH inventory_velocity AS (
    SELECT
      p.product_id,
      p.product_name,
      p.category,
      i.quantity_on_hand,
      i.quantity_on_hand * p.cost as inventory_value,
      COALESCE(SUM(ti.quantity), 0) as units_sold_30d,
      CASE 
        WHEN AVG(ti.quantity) > 0 THEN i.quantity_on_hand / AVG(ti.quantity)
        ELSE 999
      END as days_of_stock,
      CASE
        WHEN MAX(t.transaction_date) < CURRENT_DATE - INTERVAL '30 days' THEN 'Dead Stock'
        WHEN MAX(t.transaction_date) < CURRENT_DATE - INTERVAL '14 days' THEN 'Slow Moving'
        WHEN i.quantity_on_hand / NULLIF(AVG(ti.quantity), 0) > 60 THEN 'Overstock'
        ELSE 'Normal'
      END as stock_status,
      CASE 
        WHEN p.category = 'Snacks' THEN 'Bundle with Softdrinks'
        WHEN p.category = 'Personal Care' THEN 'Buy 2 Take 1 Promo'
        WHEN p.category = 'Tobacco' THEN 'Pair with Coffee'
        ELSE 'Discount 10-15%'
      END as liquidation_strategy
    FROM scout.dim_inventory i
    JOIN scout.dim_products p ON i.product_id = p.product_id
    LEFT JOIN scout.fact_transaction_items ti ON p.product_id = ti.product_id
    LEFT JOIN scout.fact_transactions t ON ti.transaction_id = t.transaction_id 
      AND t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY p.product_id, p.product_name, p.category, i.quantity_on_hand, p.cost
  )
  SELECT * FROM inventory_velocity
  WHERE stock_status IN ('Dead Stock', 'Slow Moving', 'Overstock')
  ORDER BY inventory_value DESC;
$$;

-- Function for Supplier Stockout Analysis
create or replace function scout.get_stockout_analysis()
returns table(
  supplier_id text,
  supplier_name text,
  category text,
  selling_days bigint,
  stockout_days bigint,
  frequently_stocked_out text,
  suggested_reorder_point numeric,
  delivery_recommendation text
)
language sql
security definer
as $$
  WITH stockout_analysis AS (
    SELECT
      p.supplier_id,
      sup.supplier_name,
      p.category,
      COUNT(DISTINCT DATE(t.transaction_date)) as selling_days,
      COUNT(DISTINCT CASE 
        WHEN i.quantity_on_hand = 0 THEN DATE(t.transaction_date) 
      END) as stockout_days,
      STRING_AGG(DISTINCT 
        CASE WHEN i.quantity_on_hand = 0 THEN p.product_name END, ', '
      ) as frequently_stocked_out,
      AVG(ti.quantity) * 3 as suggested_reorder_point,
      CASE
        WHEN COUNT(DISTINCT CASE WHEN i.quantity_on_hand = 0 THEN DATE(t.transaction_date) END) > 5 
          THEN 'Increase to 2x/week'
        WHEN AVG(ti.quantity) > 100 THEN 'Weekly delivery OK'
        ELSE 'Bi-weekly sufficient'
      END as delivery_recommendation
    FROM scout.fact_transactions t
    JOIN scout.fact_transaction_items ti ON t.transaction_id = ti.transaction_id
    JOIN scout.dim_products p ON ti.product_id = p.product_id
    JOIN scout.dim_inventory i ON p.product_id = i.product_id
    JOIN scout.dim_suppliers sup ON p.supplier_id = sup.supplier_id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY 1,2,3
  )
  SELECT * FROM stockout_analysis
  ORDER BY stockout_days DESC;
$$;

-- Grant execute permissions
grant execute on function scout.get_tingi_economics to anon, authenticated;
grant execute on function scout.get_credit_behavior to anon, authenticated;
grant execute on function scout.get_inventory_velocity to anon, authenticated;
grant execute on function scout.get_stockout_analysis to anon, authenticated;