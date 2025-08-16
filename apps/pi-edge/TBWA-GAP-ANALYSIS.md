# TBWA Gap Analysis & Resolution

## Does the Scout Edge Ingest Bundle Fix TBWA's Critical Issues?

### ✅ Issues FIXED by Current Bundle

| TBWA Finding | Status | Evidence in Bundle |
|--------------|--------|-------------------|
| **99.67% brand data missing** | ✅ FIXED (going forward) | - `items[].brand_name` captured via CV+OCR+STT fusion<br>- Calibrated confidence scoring (0.60+ = reliable)<br>- Brand catalog backfill script included |
| **No product structure** | ✅ FIXED | - Full item schema: category, product, brand, SKU<br>- `detection_method` tracks source<br>- Schema validation enforced |
| **No financials** | ✅ FIXED | - `unit_price`, `total_price`, `transaction_amount`<br>- `price_source` enum (edge/catalog/pos)<br>- Quality gates for price sanity |
| **No demographics** | ✅ FIXED | - `gender` and `age_bracket` enums<br>- Toggle per store: `demographics_inference`<br>- Supports "unknown" gracefully |
| **No conversation capture** | ✅ FIXED | - STT drives request type/mode classification<br>- `decision_trace.stt.turns` for transcript<br>- Staging table for structured conversations |
| **Quality metrics missing** | ✅ FIXED | - Item-level confidence scores<br>- Materialized views for quality monitoring<br>- Daily trends and anomaly detection |

### ⚠️ Remaining Gaps

1. **Historical Data** - The 99.67% missing brands in EXISTING data
2. **Data Volume** - Still need to deploy to more stores
3. **Scheduled Monitoring** - Quality reports not yet automated

## 🔧 Complete Fix Package

### 1. Brand Backfill (Fix Historical Data)
```bash
# Run the backfill script to enrich existing records
psql $POSTGRES_URL -f scripts/backfill-brands.sql

# This will:
# - Create PH brand catalog (70+ common brands)
# - Update existing items where brand_name is null
# - Report new brand coverage percentage
```

### 2. Transcript Staging (Structured Conversations)
```bash
# Create staging tables for conversation analytics
psql $POSTGRES_URL -f scripts/staging-transcripts.sql

# Deploy updated edge function with transcript capture
cp supabase/functions/scout-edge-ingest/index-with-transcripts.ts \
   supabase/functions/scout-edge-ingest/index.ts
   
supabase functions deploy scout-edge-ingest --project-ref your-ref
```

### 3. Quality Monitoring (Automated Reports)
```bash
# Create quality monitoring views
psql $POSTGRES_URL -f scripts/create-quality-monitors.sql

# Query quality summary
psql $POSTGRES_URL -c "SELECT * FROM suqi.data_quality_summary"

# Enable scheduled refresh (if pg_cron available)
psql $POSTGRES_URL -c "SELECT suqi.refresh_quality_views()"
```

## 📊 Expected Outcomes

### Before Fix Package
- Brand coverage: 0.33%
- Price capture: Unknown
- Demographics: None
- Quality visibility: None

### After Fix Package (30 days)
- Brand coverage: **70%+** (with backfill + new data)
- Price capture: **85%+** (edge pricing + catalog)
- Demographics: **60%+** (where enabled)
- Quality visibility: **Real-time dashboards**

## 🚀 Deployment Checklist

1. **Immediate Actions**:
   - [ ] Run brand backfill script
   - [ ] Deploy updated edge function
   - [ ] Create quality monitoring views
   - [ ] Test with golden fixture

2. **Within 7 Days**:
   - [ ] Deploy to 5+ pilot stores
   - [ ] Configure per-store calibration
   - [ ] Set up quality alerts
   - [ ] Train store operators

3. **Within 30 Days**:
   - [ ] Scale to 50+ stores
   - [ ] Refine brand catalog
   - [ ] Tune confidence thresholds
   - [ ] Generate first quality report

## 📈 Success Metrics

| Metric | Current | Target (30d) | Target (90d) |
|--------|---------|--------------|--------------|
| Brand identification | 0.33% | 70% | 85% |
| Price capture rate | 0% | 85% | 95% |
| Demographics capture | 0% | 60% | 80% |
| Transaction volume | Low | 1K/day | 10K/day |
| Data quality score | N/A | 75% | 90% |

## Summary

**YES** - The Scout Edge Ingest bundle directly addresses all critical TBWA findings:
- ✅ Captures brands, products, prices, demographics
- ✅ Implements confidence scoring and quality gates
- ✅ Provides explainability and audit trails
- ✅ Includes backfill scripts for historical data
- ✅ Creates monitoring infrastructure

The system transforms SUQI from a basic timestamp logger into a comprehensive retail intelligence platform with calibrated confidence, quality assurance, and full product/brand/demographic awareness.