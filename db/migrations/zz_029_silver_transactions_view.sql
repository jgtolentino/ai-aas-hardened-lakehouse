-- 029_silver_transactions_view.sql
-- Create Silver transactions flat view for comparison with Gold

CREATE OR REPLACE VIEW scout.v_silver_transactions_flat AS
SELECT
  st.transaction_id, 
  st.store_id, 
  st.ts AS full_timestamp,
  st.total_amount, 
  st.discount_amount, 
  st.tax_amount, 
  st.net_amount,
  st.payment_method, 
  st.basket_size, 
  st.peso_value,
  st.source_file,
  CASE 
    WHEN st.source_file LIKE '%.zip' THEN 'ZIP'
    WHEN st.source_file LIKE '%.json' THEN 'JSON'
    WHEN st.source_file LIKE '%.csv' THEN 'CSV'
    ELSE 'OTHER' 
  END AS source_type,
  st.created_at
FROM scout.silver_transactions st
ORDER BY st.ts DESC;

-- Grant access to the Silver view
GRANT SELECT ON scout.v_silver_transactions_flat TO anon, authenticated, dash_ro;

-- Also ensure Gold view has proper grants
GRANT SELECT ON scout.v_gold_transactions_flat TO anon, authenticated, dash_ro;

-- Ensure schema usage is granted
GRANT USAGE ON SCHEMA scout TO anon, authenticated, dash_ro;