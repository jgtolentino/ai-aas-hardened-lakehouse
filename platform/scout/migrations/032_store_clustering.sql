-- ============================================================
-- Migration 032: Store Clustering
-- Creates store clustering tables for competitive analysis
-- ============================================================

-- Store clusters for grouping similar stores
CREATE TABLE IF NOT EXISTS scout.store_clusters (
    cluster_id SERIAL PRIMARY KEY,
    store_id VARCHAR(100) REFERENCES scout.dim_stores(store_id),
    cluster_name VARCHAR(100) NOT NULL,
    cluster_type VARCHAR(50) CHECK (cluster_type IN ('size', 'location', 'performance', 'demographic')),
    cluster_attributes JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(store_id, cluster_type)
);

-- Cluster definitions
CREATE TABLE IF NOT EXISTS scout.cluster_definitions (
    cluster_name VARCHAR(100) PRIMARY KEY,
    cluster_type VARCHAR(50),
    description TEXT,
    criteria JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert default cluster definitions
INSERT INTO scout.cluster_definitions (cluster_name, cluster_type, description, criteria) VALUES
    ('Metro High Traffic', 'location', 'High-traffic stores in metro areas', 
     '{"min_daily_transactions": 100, "location": ["Metro Manila", "Cebu City", "Davao City"]}'),
    ('Provincial Medium', 'location', 'Medium-traffic provincial stores',
     '{"min_daily_transactions": 30, "max_daily_transactions": 100, "location_type": "provincial"}'),
    ('Neighborhood Small', 'location', 'Small neighborhood sari-sari stores',
     '{"max_daily_transactions": 30, "store_size": "small"}'),
    ('Premium Segment', 'demographic', 'Stores in high-income areas',
     '{"avg_ticket_size": ">500", "premium_brand_share": ">0.3"}'),
    ('Value Segment', 'demographic', 'Stores in price-sensitive areas',
     '{"avg_ticket_size": "<200", "value_brand_share": ">0.5"}'),
    ('Top Performers', 'performance', 'Top 20% by revenue',
     '{"performance_percentile": ">80"}'),
    ('Growth Stores', 'performance', 'High growth potential stores',
     '{"revenue_growth_3m": ">0.2", "new_customer_rate": ">0.3"}')
ON CONFLICT (cluster_name) DO NOTHING;

-- Function to auto-assign stores to clusters
CREATE OR REPLACE FUNCTION scout.assign_store_clusters()
RETURNS void AS $$
BEGIN
    -- Clear existing clusters
    DELETE FROM scout.store_clusters WHERE cluster_type IN ('location', 'performance');
    
    -- Assign location-based clusters
    INSERT INTO scout.store_clusters (store_id, cluster_name, cluster_type, cluster_attributes)
    WITH store_metrics AS (
        SELECT 
            s.store_id,
            s.city_municipality,
            COUNT(DISTINCT ft.transaction_id) / 30.0 AS avg_daily_transactions,
            AVG(ft.total_amount) AS avg_ticket,
            SUM(ft.total_amount) AS total_revenue_30d
        FROM scout.dim_stores s
        LEFT JOIN scout.fact_transactions ft ON s.store_key = ft.store_key
        WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY s.store_id, s.city_municipality
    )
    SELECT 
        store_id,
        CASE 
            WHEN city_municipality IN ('Quezon City', 'Makati', 'Cebu City', 'Davao City') 
                 AND avg_daily_transactions >= 100 THEN 'Metro High Traffic'
            WHEN avg_daily_transactions BETWEEN 30 AND 100 THEN 'Provincial Medium'
            ELSE 'Neighborhood Small'
        END AS cluster_name,
        'location' AS cluster_type,
        jsonb_build_object(
            'avg_daily_transactions', ROUND(avg_daily_transactions::NUMERIC, 2),
            'avg_ticket', ROUND(avg_ticket::NUMERIC, 2),
            'city', city_municipality
        ) AS cluster_attributes
    FROM store_metrics;
    
    -- Assign performance-based clusters
    INSERT INTO scout.store_clusters (store_id, cluster_name, cluster_type, cluster_attributes)
    WITH store_performance AS (
        SELECT 
            s.store_id,
            SUM(ft.total_amount) AS revenue_30d,
            PERCENT_RANK() OVER (ORDER BY SUM(ft.total_amount)) * 100 AS revenue_percentile,
            (SUM(ft.total_amount) - LAG(SUM(ft.total_amount)) OVER (PARTITION BY s.store_id ORDER BY s.store_id)) 
                / NULLIF(LAG(SUM(ft.total_amount)) OVER (PARTITION BY s.store_id ORDER BY s.store_id), 0) AS growth_rate
        FROM scout.dim_stores s
        LEFT JOIN scout.fact_transactions ft ON s.store_key = ft.store_key
        WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY s.store_id
    )
    SELECT 
        store_id,
        CASE 
            WHEN revenue_percentile >= 80 THEN 'Top Performers'
            WHEN growth_rate > 0.2 THEN 'Growth Stores'
            ELSE NULL
        END AS cluster_name,
        'performance' AS cluster_type,
        jsonb_build_object(
            'revenue_30d', ROUND(revenue_30d::NUMERIC, 2),
            'revenue_percentile', ROUND(revenue_percentile::NUMERIC, 1),
            'growth_rate', ROUND(COALESCE(growth_rate, 0)::NUMERIC, 3)
        ) AS cluster_attributes
    FROM store_performance
    WHERE revenue_percentile >= 80 OR growth_rate > 0.2;
    
END;
$$ LANGUAGE plpgsql;

-- Create indexes
CREATE INDEX idx_store_clusters_store ON scout.store_clusters(store_id);
CREATE INDEX idx_store_clusters_name ON scout.store_clusters(cluster_name);
CREATE INDEX idx_store_clusters_type ON scout.store_clusters(cluster_type);

-- View for cluster summaries
CREATE OR REPLACE VIEW scout.v_cluster_performance AS
SELECT 
    sc.cluster_name,
    sc.cluster_type,
    COUNT(DISTINCT sc.store_id) AS store_count,
    AVG((sc.cluster_attributes->>'avg_daily_transactions')::NUMERIC) AS avg_daily_txns,
    AVG((sc.cluster_attributes->>'revenue_30d')::NUMERIC) AS avg_revenue,
    cd.description,
    cd.criteria
FROM scout.store_clusters sc
JOIN scout.cluster_definitions cd ON sc.cluster_name = cd.cluster_name
GROUP BY sc.cluster_name, sc.cluster_type, cd.description, cd.criteria
ORDER BY sc.cluster_type, store_count DESC;

-- Schedule cluster assignment
SELECT cron.schedule(
    'assign-store-clusters',
    '0 3 * * *', -- 3 AM daily
    'SELECT scout.assign_store_clusters();'
);