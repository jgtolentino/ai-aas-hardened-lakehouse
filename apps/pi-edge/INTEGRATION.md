# Scout Edge Integration Guide

## Quick Start

### 1. Set Environment Variables

```bash
# Required for deployment
export SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
export SUPABASE_SERVICE_ROLE_KEY="your-service-key-here"
export POSTGRES_URL="postgresql://postgres:password@db.host.supabase.co:5432/postgres"

# For edge devices
export PI_HOST="pi@192.168.1.44"
export SUPABASE_FUNC_URL="https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/scout-edge-ingest"
```

### 2. Deploy to Supabase

```bash
# Run deployment script
./scripts/deploy.sh
```

### 3. Configure Edge Device

```bash
# SSH to Pi and create directories
ssh $PI_HOST "sudo mkdir -p /opt/scout-edge/app && sudo chown -R \$USER:\$USER /opt/scout-edge"

# Copy configuration files
scp edge-device/app/* $PI_HOST:/opt/scout-edge/app/
scp edge-device/scout-edge.service $PI_HOST:/tmp/

# Install service
ssh $PI_HOST "sudo mv /tmp/scout-edge.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now scout-edge"
```

### 4. Test the System

```bash
# Test with golden fixture
curl -sS -X POST "$SUPABASE_FUNC_URL" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @fixtures/golden.json | jq .

# Expected response:
# {"ok": true}
```

## Integration with Existing Systems

### Database Schema

The system creates three tables:
- `scout_gold_transactions` - Main transaction records
- `scout_gold_transaction_items` - Individual items per transaction
- `edge_decision_trace` - Optional explainability data

### API Endpoint

```
POST https://your-project.supabase.co/functions/v1/scout-edge-ingest
Authorization: Bearer <anon-key>
Content-Type: application/json

{
  "transaction_id": "TXN-...",
  "store": {...},
  "items": [...],
  ...
}
```

### Dashboard Integration

Query examples for your Scout Dashboard:

```sql
-- Daily transaction volume
SELECT 
  DATE(ts_utc) as date,
  COUNT(*) as transactions,
  SUM(transaction_amount) as total_amount
FROM scout_gold_transactions
GROUP BY DATE(ts_utc)
ORDER BY date DESC;

-- Top products by confidence
SELECT 
  product_name,
  brand_name,
  AVG(confidence) as avg_confidence,
  COUNT(*) as occurrences
FROM scout_gold_transaction_items
WHERE confidence >= 0.60
GROUP BY product_name, brand_name
ORDER BY occurrences DESC
LIMIT 20;

-- Substitution patterns
SELECT 
  a.brand_name as requested,
  b.brand_name as substituted,
  COUNT(*) as count
FROM scout_gold_transactions t
JOIN catalog_brands a ON t.asked_brand_id = a.id
JOIN catalog_brands b ON t.final_brand_id = b.id
WHERE t.asked_brand_id != t.final_brand_id
GROUP BY a.brand_name, b.brand_name
ORDER BY count DESC;
```

## Monitoring & Alerts

### Health Check

```bash
# Check edge function status
curl -I https://your-project.supabase.co/functions/v1/scout-edge-ingest

# Check recent transactions
psql "$POSTGRES_URL" -c "
  SELECT COUNT(*) as last_hour_count 
  FROM scout_gold_transactions 
  WHERE ts_utc > NOW() - INTERVAL '1 hour'
"
```

### Key Metrics

Monitor these in your observability platform:
- Transaction ingestion rate (target: >100/hour during peak)
- Average confidence score (target: >0.75)
- Error rate (target: <1%)
- Latency P95 (target: <500ms)

## Troubleshooting

### Common Issues

1. **401 Unauthorized**
   - Check authorization header format: `Bearer <token>`
   - Verify anon key is correct

2. **Schema validation errors**
   - Check all required fields are present
   - Verify enum values are valid
   - Ensure confidence scores are between 0-1

3. **Database connection issues**
   - Verify POSTGRES_URL is correct
   - Check network connectivity
   - Ensure tables exist (run init_gold.sql)

### Debug Mode

Add `decision_trace` to payload for explainability:

```json
{
  ...
  "decision_trace": {
    "vision": [...],
    "stt": {...},
    "fusion": {...}
  }
}
```

This will be stored separately for debugging without affecting gold data.