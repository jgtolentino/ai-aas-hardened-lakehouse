#!/bin/bash
# Generate combined Scout v5.2 migrations SQL

echo "-- Scout v5.2 Combined Migrations (026-032)"
echo "-- Generated: $(date)"
echo "-- Copy this SQL and run in Supabase SQL Editor"
echo ""

# List of migrations
MIGRATIONS=(
    "026_edge_device_schema.sql"
    "027_stt_detection_schema.sql"
    "028_standardize_dim_names.sql"
    "029_silver_line_items.sql"
    "030_competitive_geo_intelligence.sql"
    "031_fact_substitutions_table.sql"
    "032_store_clustering.sql"
)

# Concatenate all migrations
for migration in "${MIGRATIONS[@]}"; do
    echo ""
    echo "-- ============================================"
    echo "-- Migration: $migration"
    echo "-- ============================================"
    echo ""
    cat "platform/scout/migrations/$migration"
    echo ""
done

echo ""
echo "-- ============================================"
echo "-- Post-migration health checks"
echo "-- ============================================"
echo ""
echo "-- Check edge devices"
echo "SELECT COUNT(*) as edge_devices FROM scout.edge_health;"
echo ""
echo "-- Check STT triggers"
echo "SELECT COUNT(*) as stt_triggers FROM scout.stt_brand_triggers;"
echo ""
echo "-- Check competitive views"
echo "SELECT COUNT(*) as records FROM scout.gold_brand_competitive_30d LIMIT 1;"
echo ""
echo "-- Check substitutions"
echo "SELECT COUNT(*) as substitutions FROM scout.fact_substitutions;"
echo ""
echo "-- Check store clusters"
echo "SELECT COUNT(DISTINCT cluster_id) as clusters FROM scout.store_clusters;"