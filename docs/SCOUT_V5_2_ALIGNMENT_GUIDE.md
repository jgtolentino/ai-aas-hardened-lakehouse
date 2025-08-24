# 📘 Scout Analytics v5.2 Alignment Guide

## Overview

This guide explains how to align your existing Scout deployment with the comprehensive PRD requirements while **preserving all existing data and functionality**.

---

## 🎯 Current State vs Target State

### What You Have (Deployed)

Based on the deployment audit, your Scout system currently has:

✅ **Existing Components:**
- Bronze layer (`bronze_transactions_raw`)
- Silver layer (`silver_transactions`)
- Gold layer (`gold_fact_transactions_enhanced`)
- Reference tables (`ref_brands`, `ref_categories`)
- Dimension tables with **singular names** (`dim_store`, `dim_sku`, `dim_customer`)
- Edge device monitoring (`edge_health`, `edge_devices`)
- Installation checks system
- Connectivity layer functions
- 110 tables, 143 views, 245 RPCs

⚠️ **Naming Pattern:** Your system uses singular dimension names (e.g., `dim_store`), while the PRD expects plural names (e.g., `dim_stores`).

### What PRD Expects

The PRD specification requires:

📋 **Required Components:**
- Fact tables (`fact_transactions`, `fact_transaction_items`, `fact_daily_sales`)
- Date and time dimensions (`dim_date`, `dim_time`)
- Dimension tables with **plural names** (`dim_stores`, `dim_products`)
- Master tables for operational data
- STT (Speech-to-Text) tables
- Platinum layer for predictive analytics
- ETL pipeline status tracking
- Core RPC functions (`get_dashboard_kpis`, `get_sales_trend`)

---

## 🔧 The Alignment Patch

The patch (`20250824160000_scout_v5_2_alignment_patch.sql`) bridges the gap by:

### 1. **Adding Missing Tables** (Non-Destructive)
```sql
-- Adds fact tables without touching existing data
CREATE TABLE IF NOT EXISTS scout.fact_transactions (...);
CREATE TABLE IF NOT EXISTS scout.fact_transaction_items (...);
CREATE TABLE IF NOT EXISTS scout.fact_daily_sales (...);

-- Adds missing dimensions
CREATE TABLE IF NOT EXISTS scout.dim_date (...);
CREATE TABLE IF NOT EXISTS scout.dim_time (...);
```

### 2. **Creating Compatibility Views** (Handles Naming)
```sql
-- Maps plural names to existing singular tables
CREATE OR REPLACE VIEW scout.dim_stores AS SELECT * FROM scout.dim_store;
CREATE OR REPLACE VIEW scout.dim_products AS SELECT * FROM scout.dim_sku;
CREATE OR REPLACE VIEW scout.dim_customers AS SELECT * FROM scout.dim_customer;

-- Maps master tables to existing ref tables
CREATE OR REPLACE VIEW scout.master_brands AS SELECT * FROM scout.ref_brands;
CREATE OR REPLACE VIEW scout.master_categories AS SELECT * FROM scout.ref_categories;
```

### 3. **Adding STT & Platinum Tables**
```sql
-- Speech-to-text support
CREATE TABLE IF NOT EXISTS scout.stt_brand_dictionary (...);
CREATE TABLE IF NOT EXISTS scout.stt_detections (...);

-- Predictive analytics
CREATE TABLE IF NOT EXISTS scout.platinum_substitution_patterns (...);
CREATE TABLE IF NOT EXISTS scout.platinum_demand_forecast (...);
```

### 4. **Core RPC Functions**
```sql
-- Dashboard KPIs
CREATE OR REPLACE FUNCTION scout.get_dashboard_kpis(...);

-- Sales trends
CREATE OR REPLACE FUNCTION scout.get_sales_trend(...);
```

---

## 📝 Deployment Steps

### Step 1: Validate Current State
```bash
# Run validation to see what exists
psql $DATABASE_URL -f scripts/validate_scout_alignment.sql
```

### Step 2: Apply the Patch
```bash
# Apply alignment patch (safe - uses IF NOT EXISTS)
psql $DATABASE_URL -f supabase/migrations/20250824160000_scout_v5_2_alignment_patch.sql
```

### Step 3: Populate Dimension Tables
```sql
-- Date and time dimensions are auto-populated by the patch
-- Fact tables can be populated from existing data if needed:
SELECT scout.migrate_to_fact_tables();
```

### Step 4: Test Core Functions
```sql
-- Test dashboard KPIs
SELECT scout.get_dashboard_kpis('2025-08-01', '2025-08-24');

-- Test sales trend
SELECT scout.get_sales_trend(30, 'daily');

-- Test connectivity dashboard
SELECT * FROM scout.get_connectivity_dashboard();
```

---

## 🔄 How It Works

### Naming Compatibility

The patch creates a **dual-naming system** that supports both conventions:

```
Physical Table: dim_store (your existing)
         ↓
View: dim_stores (PRD expects)
         ↓
Both names work!
```

This means:
- Existing code using `dim_store` continues to work
- New code expecting `dim_stores` also works
- No data migration required

### Master vs Reference Tables

Your system uses `ref_` prefix, PRD expects `master_` prefix:

```
Physical Table: ref_brands (your existing)
         ↓
View: master_brands (PRD expects)
         ↓
Both names work!
```

### Fact Table Population

If you have existing transaction data in `silver_transactions`, the migration function can populate the new fact tables:

```sql
-- Optional: Migrate existing data to fact tables
SELECT scout.migrate_to_fact_tables();
```

---

## ✅ Post-Deployment Verification

### Check All Systems
```sql
-- Verify complete installation
SELECT scout.validate_complete_installation();
```

Expected output:
```json
{
  "overall_score": 95,
  "status": "excellent",
  "master_data": {
    "brands": {"count": 36, "status": "complete"},
    "categories": {"count": 19, "status": "complete"}
  },
  "system_capabilities": {
    "auto_registration": "enabled",
    "health_monitoring": "enabled",
    "installation_checks": "enabled",
    "predictive_maintenance": "enabled"
  }
}
```

### Test API Endpoints
```bash
# Test via Supabase REST API
curl -X POST \
  https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/get_dashboard_kpis \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"p_date_from": "2025-08-01", "p_date_to": "2025-08-24"}'
```

---

## 🚀 Benefits of This Approach

1. **Zero Downtime** - All changes are additive
2. **No Data Loss** - Existing tables untouched
3. **Backward Compatible** - Old code continues to work
4. **Forward Compatible** - Supports PRD requirements
5. **Flexible Naming** - Both conventions supported
6. **Easy Rollback** - Just drop the new objects if needed

---

## 📊 Architecture After Patch

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Your Tables   │     │ Compat. Views   │     │  PRD Expects    │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ dim_store       │ --> │ dim_stores      │ <-- │ dim_stores      │
│ dim_sku         │ --> │ dim_products    │ <-- │ dim_products    │
│ ref_brands      │ --> │ master_brands   │ <-- │ master_brands   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         ↓                                               ↓
    Works with                                      Works with
   existing code                                    new PRD code
```

---

## 🎯 Summary

The alignment patch:
- ✅ Adds all missing PRD components
- ✅ Preserves your existing deployment
- ✅ Handles naming differences elegantly
- ✅ Enables full PRD functionality
- ✅ Maintains backward compatibility

Your Scout Analytics v5.2 system will be **fully PRD-compliant** while keeping all your existing work intact!