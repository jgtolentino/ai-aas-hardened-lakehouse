# Scout Edge Quality Monitoring & Alerting System

## Overview

Complete quality monitoring infrastructure with automated confusion matrix evaluation, KPI tracking, and integration with ClickUp/GitHub for incident management.

## 🎯 What This Solves

1. **Automated Quality Tracking** - Hourly confusion matrix updates
2. **KPI Monitoring** - Brand F1 scores, coverage metrics, drift detection
3. **Operational Alerts** - ClickUp tasks and GitHub issues for quality incidents
4. **Store-Level Analysis** - Identify problematic locations
5. **Deduplication** - Prevents alert spam with incident keys

## 📊 Key Metrics Tracked

### Brand Performance (Per-Brand)
- **Recall**: % of actual brand X correctly identified
- **Precision**: % of predicted brand X that are correct
- **F1 Score**: Harmonic mean of recall and precision

### System-Wide Metrics
- **Macro F1**: Average F1 across all brands (alerting threshold: 0.70)
- **Brand Coverage**: % of items with identified brands (target: >80%)
- **Price Capture**: % of items with prices (target: >80%)
- **Demographics Coverage**: % of transactions with demographics
- **Confidence Distribution**: % of low-confidence items (<0.60)

### Operational Metrics
- **Store Accuracy**: Per-store brand identification accuracy
- **Confusion Patterns**: Most common brand misidentifications
- **Data Freshness**: Time since last transaction

## 🚀 Setup Instructions

### 1. Database Setup
```bash
# Set connection
export POSTGRES_URL="postgresql://user:pass@host/db"

# Run complete setup
./scripts/setup-quality-monitoring.sh
```

### 2. Deploy Quality Sentinel
```bash
# Set secrets in Supabase dashboard
supabase secrets set \
  CLICKUP_TOKEN="your-clickup-token" \
  CLICKUP_LIST_ID="your-list-id" \
  GITHUB_TOKEN="your-github-token" \
  GITHUB_REPO="owner/repo" \
  SENTINEL_KEY="random-secret-key"

# Deploy function
supabase functions deploy quality-sentinel --project-ref your-ref
```

### 3. Configure GitHub Actions
```bash
# Set repository secrets
gh secret set SUPABASE_URL --body "https://your-ref.supabase.co"
gh secret set SENTINEL_KEY --body "your-secret-key"
```

## 📈 Monitoring Dashboards

### Real-Time KPIs
```sql
-- Brand performance dashboard
SELECT * FROM suqi.v_brand_kpis ORDER BY f1_score DESC;

-- System health check
SELECT * FROM suqi.system_health_check();

-- Store accuracy trends
SELECT * FROM suqi.v_store_accuracy 
WHERE date >= current_date - 7
ORDER BY accuracy_pct ASC;

-- Top confusions
SELECT * FROM suqi.v_top_confusions;
```

### Historical Trends
```sql
-- Daily quality trends
SELECT date, brand_missing_pct, avg_confidence
FROM suqi.daily_quality_trends 
ORDER BY date DESC;

-- F1 score history
SELECT run_date, avg(f1_score) as avg_f1
FROM suqi.v_brand_kpis
GROUP BY run_date
ORDER BY run_date DESC;
```

## 🚨 Alert Thresholds

| Metric | Critical | High | Medium |
|--------|----------|------|--------|
| Macro F1 | < 0.56 | < 0.70 | < 0.80 |
| Brand Coverage | < 64% | < 80% | < 90% |
| Price Coverage | < 64% | < 80% | < 90% |
| Store Accuracy | < 56% | < 70% | < 80% |

## 🔄 Automated Workflows

### Hourly (via pg_cron)
1. Sync predictions from production
2. Compute confusion matrix (24h window)
3. Update KPI views

### Daily at 2:30 AM
1. Refresh materialized quality views
2. Clean up old alert logs

### Daily at 7:00 AM
1. Run macro F1 check
2. Send alerts if below threshold

### Hourly (via GitHub Actions)
1. Call Quality Sentinel
2. Create ClickUp/GitHub issues for new incidents
3. Fail workflow on critical issues

## 📝 Incident Management

### ClickUp Integration
- Tasks created with severity-based priority
- Due dates: Critical (4h), High (24h)
- Tags: `suqi`, `quality`, `automated`

### GitHub Issues
- Labels match severity levels
- Template includes metrics and actions
- Links back to incident key

### Incident Keys
Format: `{TYPE}:{DATE}`
- Prevents duplicate issues
- Allows tracking resolution

Examples:
- `BRAND_MISSING:2025-08-15`
- `LOW_MACRO_F1:2025-08-15`
- `CONFUSION_TOP:2025-08-15`

## 🔧 Operational Procedures

### When Macro F1 Drops
1. Check top confusions: `SELECT * FROM suqi.v_top_confusions`
2. Add variant mappings for confused pairs
3. Update STT dictionary
4. Run backfill: `SELECT scout.backfill_resolve_brands(1000)`

### When Store Accuracy Drops
1. Identify problem stores: `SELECT * FROM suqi.detect_store_drift()`
2. Check environmental factors (lighting, camera)
3. Schedule field audit
4. Retrain/recalibrate if needed

### When Brand Coverage Drops
1. Check unrecognized brands: `SELECT * FROM scout.v_brands_unrecognized`
2. Add to brand catalog/dictionary
3. Update resolver thresholds if needed

## 📊 Sample Outputs

### Health Check
```
check_name       | status | metric | threshold | details
-----------------|--------|--------|-----------|---------------------------
macro_f1         | alert  | 0.68   | 0.70      | Current macro F1: 0.68
brand_coverage   | ok     | 82.5   | 80.0      | Brand coverage: 82.5%
price_capture    | ok     | 85.3   | 80.0      | Price capture: 85.3%
active_stores    | ok     | 15     | 10.0      | 15 stores active in last 24h
data_freshness   | ok     | 12     | 60.0      | Last transaction: 12 minutes ago
```

### Brand KPIs
```
brand       | true_pos | false_neg | false_pos | recall | precision | f1_score
------------|----------|-----------|-----------|--------|-----------|----------
COCA COLA   | 523      | 12        | 8         | 0.977  | 0.985     | 0.981
LUCKY ME    | 412      | 23        | 15        | 0.947  | 0.965     | 0.956
SAN MIGUEL  | 289      | 34        | 22        | 0.895  | 0.929     | 0.912
```

### Quality Sentinel Response
```json
{
  "ok": true,
  "timestamp": "2025-08-15T10:05:23Z",
  "issues_found": 2,
  "results": [
    {
      "key": "BRAND_MISSING:2025-08-15",
      "severity": "crit",
      "clickupId": "task_abc123",
      "ghNumber": 42,
      "isNew": true
    },
    {
      "key": "CONFUSION_TOP:2025-08-15",
      "severity": "med",
      "clickupId": "task_def456",
      "ghNumber": 43,
      "isNew": true
    }
  ]
}
```

## 🛠️ Troubleshooting

### No Confusion Matrix Data
1. Check if predictions are synced: `SELECT count(*) FROM suqi.brand_predictions`
2. Ensure ground truth exists: `SELECT count(*) FROM suqi.ground_truth_brands`
3. Run manual sync: `SELECT suqi.sync_brand_predictions()`

### Alerts Not Firing
1. Check pg_cron jobs: `SELECT * FROM cron.job WHERE jobname LIKE 'suqi_%'`
2. Verify GitHub Action runs: Check Actions tab
3. Test Sentinel manually: `curl -X POST $FUNC_URL -H "x-sentinel-key: $KEY"`

### High False Positive Rate
1. Review threshold settings in confusion-kpis.sql
2. Check calibration: May need to adjust confidence thresholds
3. Audit ground truth data quality