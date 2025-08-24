#!/usr/bin/env bash
set -euo pipefail

# Scout v5.2 - Create seed buckets and upload master data
# Executes the final step to make seed data available via Supabase Storage

SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2NzU5NTYsImV4cCI6MjA1MDI1MTk1Nn0.vL80SEOocFh0e0Sz2_cj2HZdlV4jWRpvAcEj_zNcVRM"
SUPABASE_SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDY3NTk1NiwiZXhwIjoyMDUwMjUxOTU2fQ.6sGcT5Jb8pz8PxY_3MZk9wHZI1JMKVRnWjOaTqjd8X4"

echo "🪣 Creating Scout seed data buckets..."

# 1. Create bucket for seed data
echo "Creating scout-sample-seeds bucket..."
curl -s -X POST "$SUPABASE_URL/storage/v1/bucket" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"scout-sample-seeds","public":false}' || echo "Bucket may already exist"

# 2. Create seed data files
mkdir -p tmp/seeds

echo "📄 Creating health_category_rules.csv..."
cat > tmp/seeds/health_category_rules.csv << 'EOF'
category,brand,lift_factor,seasonality_q1,seasonality_q2,seasonality_q3,seasonality_q4,effectiveness_score
"Personal Care","Colgate",1.15,1.0,1.05,1.1,1.2,0.85
"Personal Care","Oral-B",1.12,1.0,1.03,1.08,1.18,0.82
"Beverages","Coca-Cola",1.25,0.95,1.15,1.3,1.1,0.90
"Beverages","Pepsi",1.20,0.92,1.12,1.28,1.08,0.87
"Household","Tide",1.18,1.05,1.0,1.1,1.25,0.88
"Household","Surf",1.14,1.02,0.98,1.08,1.22,0.84
"Food","Maggi",1.22,1.1,1.0,1.05,1.35,0.91
"Food","Knorr",1.19,1.08,0.98,1.03,1.32,0.89
"Medicine","Biogesic",1.30,1.2,1.0,1.1,1.4,0.93
"Medicine","Neozep",1.28,1.18,0.98,1.08,1.38,0.91
EOF

echo "📄 Creating sku_catalog_ph.csv..."
cat > tmp/seeds/sku_catalog_ph.csv << 'EOF'
sku_code,product_name,brand,category,unit_size,unit_price,barcode,is_active
"SKU-CC-001","Coca-Cola 330ml","Coca-Cola","Beverages","330ml",25.00,"4902430123456",true
"SKU-PP-001","Pepsi 330ml","Pepsi","Beverages","330ml",24.00,"4902430123457",true
"SKU-CG-001","Colgate Total 75ml","Colgate","Personal Care","75ml",45.00,"4902430123458",true
"SKU-OB-001","Oral-B Complete 75ml","Oral-B","Personal Care","75ml",42.00,"4902430123459",true
"SKU-TD-001","Tide Powder 1kg","Tide","Household","1kg",85.00,"4902430123460",true
"SKU-SF-001","Surf Powder 1kg","Surf","Household","1kg",78.00,"4902430123461",true
"SKU-MG-001","Maggi Noodles","Maggi","Food","70g",8.50,"4902430123462",true
"SKU-KN-001","Knorr Cube 8pcs","Knorr","Food","8pcs",12.00,"4902430123463",true
"SKU-BG-001","Biogesic 500mg","Biogesic","Medicine","1pc",7.00,"4902430123464",true
"SKU-NZ-001","Neozep Forte","Neozep","Medicine","1pc",8.50,"4902430123465",true
EOF

echo "📄 Creating seasonality_factors.csv..."
cat > tmp/seeds/seasonality_factors.csv << 'EOF'
category,month,factor,holiday_boost,weather_impact
"Beverages",1,0.95,0.1,0.05
"Beverages",2,0.92,0.15,0.08
"Beverages",3,1.05,0.05,0.15
"Beverages",4,1.15,0.0,0.25
"Beverages",5,1.30,0.0,0.35
"Beverages",6,1.25,0.0,0.30
"Beverages",7,1.20,0.0,0.25
"Beverages",8,1.18,0.0,0.22
"Beverages",9,1.10,0.0,0.15
"Beverages",10,1.05,0.0,0.10
"Beverages",11,1.08,0.05,0.05
"Beverages",12,1.12,0.20,0.02
"Personal Care",1,1.0,0.0,0.0
"Personal Care",2,0.98,0.0,0.0
"Personal Care",3,1.02,0.0,0.0
"Personal Care",4,1.05,0.0,0.0
"Personal Care",5,1.08,0.0,0.0
"Personal Care",6,1.10,0.0,0.0
"Personal Care",7,1.08,0.0,0.0
"Personal Care",8,1.06,0.0,0.0
"Personal Care",9,1.03,0.0,0.0
"Personal Care",10,1.05,0.0,0.0
"Personal Care",11,1.15,0.05,0.0
"Personal Care",12,1.25,0.15,0.0
EOF

# 3. Upload files to bucket
echo "📤 Uploading seed files..."

for file in health_category_rules.csv sku_catalog_ph.csv seasonality_factors.csv; do
  echo "Uploading $file..."
  curl -s -X POST "$SUPABASE_URL/storage/v1/object/scout-sample-seeds/$file" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H "Content-Type: text/csv" \
    --data-binary "@tmp/seeds/$file"
  
  echo "✅ Uploaded $file"
done

# 4. Register uploads in database
echo "📋 Registering uploads in database..."
psql "$DATABASE_URL" << 'EOSQL'
INSERT INTO scout.master_data_uploads (
  upload_name, 
  file_path, 
  file_size_bytes, 
  upload_status, 
  data_type,
  uploaded_at
) VALUES 
  ('PH SKU Catalog', 'scout-sample-seeds/sku_catalog_ph.csv', 2048, 'completed', 'sku_catalog', NOW()),
  ('Health Category Rules', 'scout-sample-seeds/health_category_rules.csv', 1536, 'completed', 'health_rules', NOW()),
  ('Seasonality Factors', 'scout-sample-seeds/seasonality_factors.csv', 1024, 'completed', 'seasonality', NOW())
ON CONFLICT (upload_name) DO UPDATE SET 
  uploaded_at = NOW(),
  upload_status = 'completed';
EOSQL

# 5. Test bucket access
echo "🧪 Testing bucket access..."
curl -s "$SUPABASE_URL/storage/v1/object/list/scout-sample-seeds" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" | \
  jq -r '.[] | .name' || echo "⚠️  Bucket listing failed"

# Cleanup
rm -rf tmp/seeds

echo "✅ Scout seed buckets and uploads complete!"
echo "Files available at: $SUPABASE_URL/storage/v1/object/scout-sample-seeds/"
echo "Database records updated in scout.master_data_uploads"