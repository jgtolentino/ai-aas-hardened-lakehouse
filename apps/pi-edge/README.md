# Scout Edge Ingest - Supabase Edge Function

This repository contains the **Scout Edge Ingest** system for processing sari-sari store transactions with confidence scoring, explainability, and quality gates.

## 🚀 Features

- **Supabase Edge Function** for real-time transaction ingestion
- **Gold SQL Schema** for scout transaction data
- **Confidence Calibration** with Brier score and ECE metrics
- **Explainability Traces** for audit and debugging
- **Quality Gates** for data validation
- **Edge Device Configuration** for Raspberry Pi deployment

## 📁 Project Structure

```
edge-suqi-pie/
├── supabase/
│   └── functions/
│       └── scout-edge-ingest/    # Edge function for ingestion
│           ├── index.ts          # Main function handler
│           └── schema.json       # JSON Schema validation
├── sql/
│   └── init_gold.sql            # Gold tables DDL
├── edge-device/
│   ├── app/
│   │   ├── calibration.json     # Confidence calibration weights
│   │   └── config.yaml          # Device configuration
│   └── scout-edge.service       # Systemd service file
├── fixtures/
│   ├── golden.json              # Golden test fixture
│   └── calibration/
│       └── labels.jsonl         # Calibration test data
└── scripts/
    ├── deploy.sh                # Deployment script
    └── calibration_check.py     # Brier/ECE metrics

```

## 🔧 Setup & Deployment

### Prerequisites

- Supabase project with service role key
- PostgreSQL database access
- Node.js/npm for local development

### Environment Variables

```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
export SUPABASE_SERVICE_ROLE_KEY="your-service-key"
export POSTGRES_URL="postgresql://user:pass@host/db"
```

### Deploy

```bash
# Deploy everything
./scripts/deploy.sh

# Or manually:
# 1. Apply SQL schema
psql "$POSTGRES_URL" -f sql/init_gold.sql

# 2. Deploy edge function
supabase functions deploy scout-edge-ingest --project-ref your-project

# 3. Test with golden fixture
curl -X POST https://your-project.supabase.co/functions/v1/scout-edge-ingest \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d @fixtures/golden.json
```

## 📊 Data Schema

### Transaction Payload

```json
{
  "transaction_id": "TXN-20250814-102-000456",
  "store": { "id": "STO00284", "tz_offset_min": 480 },
  "geo": { "region_id": 13, "city_id": 1339, "barangay_id": 48291 },
  "ts_utc": "2025-08-14T12:30:00Z",
  "request": {
    "request_type": "branded|unbranded|point|indirect",
    "request_mode": "verbal|pointing|indirect",
    "payment_method": "cash|gcash|maya|credit|other",
    "gender": "male|female|unknown",
    "age_bracket": "18-24|25-34|35-44|45-54|55+|unknown"
  },
  "items": [{
    "category_name": "Beverages",
    "product_name": "Coke 1.5L",
    "qty": 2,
    "detection_method": "stt|vision|ocr|hybrid",
    "confidence": 0.96
  }],
  "suggestion": { "offered": true, "accepted": true },
  "substitution": { "asked_brand_id": 1201, "final_brand_id": 2001 },
  "amounts": { "transaction_amount": 169.0, "price_source": "edge" }
}
```

### Confidence Calibration

- **Alpha (α)**: 0.45 - Logo detection weight
- **Beta (β)**: 0.35 - OCR quality weight  
- **Gamma (γ)**: 0.20 - STT evidence weight
- **Delta (δ)**: 0.10 - Context prior weight
- **Temperature**: 1.6 - Calibration scaling
- **Min Reliable**: 0.60 - Reliability threshold

### Quality Gates

- Transcript length ≥ 12 chars
- Duration: 2-600 seconds
- At least 1 item per transaction
- Confidence ≥ 0.60 for reliability

## 🧪 Testing

### Run Calibration Check

```bash
python3 scripts/calibration_check.py
# Target: Brier ≤ 0.12, ECE ≤ 0.05
```

### Golden Fixture Test

```bash
# Test the edge function with known good data
curl -X POST $SUPABASE_FUNC_URL \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d @fixtures/golden.json | jq .
```

## 🔌 Edge Device (Raspberry Pi)

### Deploy to Pi

```bash
# Copy files
scp -r edge-device/* pi@192.168.1.44:/opt/scout-edge/

# Install service
ssh pi@192.168.1.44 "sudo cp /opt/scout-edge/scout-edge.service /etc/systemd/system/"
ssh pi@192.168.1.44 "sudo systemctl daemon-reload && sudo systemctl enable --now scout-edge"
```

### Configuration

Edit `/opt/scout-edge/app/config.yaml` on the device:
- Store ID and timezone
- STT model paths
- Camera settings
- Quality gate thresholds

## 📈 Metrics & KPIs

| Metric | Target | Description |
|--------|--------|-------------|
| Logo P@0.5 | ≥ 0.80 | Logo detection precision |
| OCR F1 | ≥ 0.85 | Brand keyword recovery |
| STT WER | ≤ 22% | Word error rate |
| Brier Score | ≤ 0.12 | Calibration quality |
| ECE | ≤ 0.05 | Expected calibration error |
| Latency | ≤ 1.0s | End-to-end processing |

## 🔐 Security & Privacy

- No raw audio/video stored
- Demographics inference can be disabled
- All data validated against JSON schema
- Bearer token authentication required

## 📝 Notes

- **Explainability traces** are stored separately in `edge_decision_trace` table
- **Gold tables** remain schema-compliant for downstream analytics
- **Confidence scores** enable quality filtering in dashboards
- **Quality gates** prevent low-quality data from entering the system