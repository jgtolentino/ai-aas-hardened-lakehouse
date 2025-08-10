-- Contract: gold_region_choropleth
-- This view is a stable API contract for regional choropleth visualization
-- Changes to this view require version bump in @tbwa/scout-contracts

CREATE OR REPLACE VIEW scout.gold_region_choropleth AS
SELECT 
    r.region_code,
    r.region_name,
    r.geom,
    COALESCE(t.total_transactions, 0) AS total_transactions,
    COALESCE(t.total_peso_value, 0) AS total_peso_value,
    COALESCE(t.unique_stores, 0) AS unique_stores,
    COALESCE(t.unique_skus, 0) AS unique_skus,
    t.date_key
FROM scout.region_gen r
LEFT JOIN scout.gold_txn_daily t ON r.region_code = t.region;

COMMENT ON VIEW scout.gold_region_choropleth IS 'Stable API v1: Regional choropleth data with geometry';