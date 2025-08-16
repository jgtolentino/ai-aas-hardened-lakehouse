-- Pragmatic performance indexes
create index if not exists ix_silver_ts on scout.silver_transactions (ts);
create index if not exists ix_silver_region_ts on scout.silver_transactions (region, ts);
create index if not exists ix_silver_category_ts on scout.silver_transactions (product_category, ts);
create index if not exists ix_subst_from_to on scout.silver_substitutions (from_sku, to_sku);

-- Optional partitioning hint (uncomment when >10M rows)
-- alter table scout.silver_transactions
--   partition by range (date_trunc('month', ts));