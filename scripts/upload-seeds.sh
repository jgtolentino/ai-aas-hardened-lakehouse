#!/bin/bash
# ============================================================
# UPLOAD SEED DATA TO SUPABASE STORAGE
# Creates bucket and uploads all CSV seed files
# ============================================================

set -e

PROJECT_REF="cxzllzyxwpyptfretryc"
BUCKET_NAME="seed-data"
DATA_DIR="./data"

echo "🚀 SCOUT SEED DATA UPLOADER"
echo "============================"
echo "Project: $PROJECT_REF"
echo "Bucket: $BUCKET_NAME"
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install with: npm i -g supabase@latest"
    exit 1
fi

# Create data directory if it doesn't exist
mkdir -p "$DATA_DIR"

# 1) Create bucket (if it doesn't exist)
echo "📦 Creating storage bucket..."
supabase storage create-bucket "$BUCKET_NAME" --public 2>/dev/null || echo "   Bucket already exists"

# 2) Generate seed CSV files if they don't exist
echo "📊 Generating seed CSV files..."

# Generate reference sources CSV
if [ ! -f "$DATA_DIR/ref_sources.csv" ]; then
    cat > "$DATA_DIR/ref_sources.csv" << 'EOF'
source_id,title,url,notes,created_at
FNRI_2021_NNS,"FNRI National Nutrition Survey 2021","https://fnri.dost.gov.ph/","Diabetes and obesity prevalence data",2025-01-24T00:00:00Z
DOH_2021_HTN,"DOH Hypertension Guidelines 2021","https://doh.gov.ph/","Hypertension dietary recommendations",2025-01-24T00:00:00Z
DOH_2021_TOB,"DOH Adult Tobacco Survey 2021","https://doh.gov.ph/","Smoking prevalence and consumption patterns",2025-01-24T00:00:00Z
PACKWORKS_2023_SEASON,"Packworks Retail Seasonality Report 2023",,"FMCG seasonal demand patterns Philippines",2025-01-24T00:00:00Z
NESTLE_2023_HEALTH,"Nestlé Philippines Health Positioning 2023",,"Brand health positioning data",2025-01-24T00:00:00Z
EOF
    echo "   ✅ Generated ref_sources.csv"
fi

# Generate categories CSV
if [ ! -f "$DATA_DIR/ref_categories.csv" ]; then
    cat > "$DATA_DIR/ref_categories.csv" << 'EOF'
category_name,parent_category_name,level,is_health_sensitive
"Beverages",,1,true
"Food & Snacks",,1,true
"Personal Care",,1,true
"Household Items",,1,false
"Tobacco & Alcohol",,1,true
"Soft Drinks","Beverages",2,true
"Energy Drinks","Beverages",2,true
"Juices","Beverages",2,true
"Water","Beverages",2,false
"Coffee & Tea","Beverages",2,true
"Processed Foods","Food & Snacks",2,true
"Snack Foods","Food & Snacks",2,true
"Dairy Products","Food & Snacks",2,true
"Condiments & Sauces","Food & Snacks",2,true
"Rice & Grains","Food & Snacks",2,false
"Health & Wellness","Personal Care",2,true
"Beauty Products","Personal Care",2,false
"Oral Care","Personal Care",2,true
"Cleaning Products","Household Items",2,false
"Cigarettes","Tobacco & Alcohol",2,true
"Alcoholic Beverages","Tobacco & Alcohol",2,true
EOF
    echo "   ✅ Generated ref_categories.csv"
fi

# Generate brands CSV
if [ ! -f "$DATA_DIR/ref_brands.csv" ]; then
    cat > "$DATA_DIR/ref_brands.csv" << 'EOF'
brand_name,brand_owner,country_origin,is_local,health_positioning
"Coca-Cola","The Coca-Cola Company","USA",false,"indulgent"
"Pepsi","PepsiCo","USA",false,"indulgent"
"Royal","Coca-Cola Beverages Philippines","Philippines",true,"neutral"
"Zest-O","Zest-O Corporation","Philippines",true,"neutral"
"Red Bull","Red Bull GmbH","Austria",false,"indulgent"
"Kopiko","Kopiko Philippines","Indonesia",false,"neutral"
"Nescafé","Nestlé Philippines","Switzerland",false,"neutral"
"Lucky Me!","Monde Nissin Corporation","Philippines",true,"neutral"
"Maggi","Nestlé Philippines","Switzerland",false,"neutral"
"Piattos","Jack n Jill","Philippines",true,"indulgent"
"Nova","Ricoa Corporation","Philippines",true,"indulgent"
"Safeguard","Procter & Gamble Philippines","USA",false,"healthy"
"Dove","Unilever Philippines","Netherlands",false,"healthy"
"Colgate","Colgate-Palmolive Philippines","USA",false,"healthy"
"Biogesic","Unilab","Philippines",true,"healthy"
"Enervon","Unilab","Philippines",true,"healthy"
"Goldilocks","Goldilocks Bakeshop","Philippines",true,"indulgent"
"Choc-Nut","Ricoa Corporation","Philippines",true,"indulgent"
"Skyflakes","Monde Nissin Corporation","Philippines",true,"neutral"
EOF
    echo "   ✅ Generated ref_brands.csv"
fi

# Generate health category rules CSV
if [ ! -f "$DATA_DIR/health_category_rules.csv" ]; then
    cat > "$DATA_DIR/health_category_rules.csv" << 'EOF'
category_name,health_flag,lift_pct,confidence_level,source_id,evidence_strength
"Soft Drinks","diabetes",0.75,0.95,"FNRI_2021_NNS","high"
"Energy Drinks","diabetes",0.70,0.95,"FNRI_2021_NNS","high"
"Juices","diabetes",0.85,0.95,"FNRI_2021_NNS","high"
"Snack Foods","diabetes",0.80,0.95,"FNRI_2021_NNS","high"
"Processed Foods","diabetes",0.85,0.95,"FNRI_2021_NNS","high"
"Health & Wellness","diabetes",1.25,0.95,"FNRI_2021_NNS","high"
"Processed Foods","hypertension",0.70,0.90,"DOH_2021_HTN","high"
"Condiments & Sauces","hypertension",0.75,0.90,"DOH_2021_HTN","high"
"Snack Foods","hypertension",0.80,0.90,"DOH_2021_HTN","high"
"Health & Wellness","hypertension",1.30,0.90,"DOH_2021_HTN","high"
"Water","hypertension",1.15,0.90,"DOH_2021_HTN","high"
"Soft Drinks","obesity",0.65,0.90,"FNRI_2021_NNS","high"
"Energy Drinks","obesity",0.70,0.90,"FNRI_2021_NNS","high"
"Snack Foods","obesity",0.75,0.90,"FNRI_2021_NNS","high"
"Health & Wellness","obesity",1.40,0.90,"FNRI_2021_NNS","high"
"Water","obesity",1.20,0.90,"FNRI_2021_NNS","high"
"Coffee & Tea","smoker",1.25,0.85,"DOH_2021_TOB","medium"
"Energy Drinks","smoker",1.15,0.85,"DOH_2021_TOB","medium"
"Alcoholic Beverages","smoker",1.20,0.85,"DOH_2021_TOB","medium"
"Health & Wellness","smoker",0.90,0.85,"DOH_2021_TOB","medium"
EOF
    echo "   ✅ Generated health_category_rules.csv"
fi

# Generate seasonality factors CSV
if [ ! -f "$DATA_DIR/seasonality_factors.csv" ]; then
    cat > "$DATA_DIR/seasonality_factors.csv" << 'EOF'
category_name,month,factor,seasonal_driver,source_id
"Beverages",3,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Beverages",4,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Beverages",5,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Soft Drinks",3,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Soft Drinks",4,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Soft Drinks",5,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Water",3,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Water",4,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Water",5,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Juices",3,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Juices",4,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Juices",5,1.25,"Hot season demand","PACKWORKS_2023_SEASON"
"Coffee & Tea",6,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Coffee & Tea",7,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Coffee & Tea",8,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Coffee & Tea",9,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Processed Foods",6,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Processed Foods",7,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Processed Foods",8,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Processed Foods",9,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Snack Foods",6,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Snack Foods",7,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Snack Foods",8,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Snack Foods",9,1.15,"Rainy season comfort consumption","PACKWORKS_2023_SEASON"
"Beverages",11,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Beverages",12,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Soft Drinks",11,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Soft Drinks",12,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Alcoholic Beverages",11,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Alcoholic Beverages",12,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Snack Foods",11,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Snack Foods",12,1.35,"Holiday season celebrations","PACKWORKS_2023_SEASON"
"Health & Wellness",6,1.20,"Back-to-school health preparation","PACKWORKS_2023_SEASON"
"Health & Wellness",1,1.40,"New Year health resolutions","PACKWORKS_2023_SEASON"
"Snack Foods",2,1.20,"Valentine celebration treats","PACKWORKS_2023_SEASON"
"Soft Drinks",2,1.20,"Valentine celebration treats","PACKWORKS_2023_SEASON"
EOF
    echo "   ✅ Generated seasonality_factors.csv"
fi

# Generate sample SKU catalog CSV
if [ ! -f "$DATA_DIR/sample_sku_catalog.csv" ]; then
    cat > "$DATA_DIR/sample_sku_catalog.csv" << 'EOF'
sku,product_name,brand,category,price,raw_metadata
"CC001","Coca-Cola 350ml","Coca-Cola","Soft Drinks",25.00,"{""size"": ""350ml"", ""package"": ""can""}"
"PP001","Pepsi 350ml","Pepsi","Soft Drinks",25.00,"{""size"": ""350ml"", ""package"": ""can""}"
"RC001","Royal Tru-Orange 350ml","Royal","Soft Drinks",20.00,"{""size"": ""350ml"", ""package"": ""can"", ""flavor"": ""orange""}"
"ZO001","Zest-O Dalandan 200ml","Zest-O","Juices",15.00,"{""size"": ""200ml"", ""package"": ""tetrapack"", ""flavor"": ""dalandan""}"
"RB001","Red Bull Energy Drink 250ml","Red Bull","Energy Drinks",65.00,"{""size"": ""250ml"", ""package"": ""can"", ""caffeine"": ""80mg""}"
"KP001","Kopiko Blanca Coffee 30g","Kopiko","Coffee & Tea",12.00,"{""size"": ""30g"", ""package"": ""sachet"", ""type"": ""3-in-1""}"
"NC001","Nescafé Original 50g","Nescafé","Coffee & Tea",85.00,"{""size"": ""50g"", ""package"": ""jar"", ""type"": ""instant""}"
"LM001","Lucky Me! Chicken 60g","Lucky Me!","Processed Foods",18.00,"{""size"": ""60g"", ""package"": ""pouch"", ""flavor"": ""chicken""}"
"MG001","Maggi Magic Sarap 50g","Maggi","Condiments & Sauces",25.00,"{""size"": ""50g"", ""package"": ""sachet"", ""type"": ""seasoning""}"
"PT001","Piattos Cheese 85g","Piattos","Snack Foods",42.00,"{""size"": ""85g"", ""package"": ""bag"", ""flavor"": ""cheese""}"
"NV001","Nova Multigrain 78g","Nova","Snack Foods",35.00,"{""size"": ""78g"", ""package"": ""bag"", ""type"": ""multigrain""}"
"SF001","Safeguard Soap 135g","Safeguard","Personal Care",45.00,"{""size"": ""135g"", ""package"": ""bar"", ""type"": ""antibacterial""}"
"DV001","Dove Beauty Bar 100g","Dove","Personal Care",55.00,"{""size"": ""100g"", ""package"": ""bar"", ""type"": ""moisturizing""}"
"CG001","Colgate Total 150g","Colgate","Oral Care",95.00,"{""size"": ""150g"", ""package"": ""tube"", ""type"": ""whitening""}"
"BG001","Biogesic 500mg 10tabs","Biogesic","Health & Wellness",75.00,"{""size"": ""10tablets"", ""package"": ""blister"", ""active"": ""paracetamol""}"
"EN001","Enervon-C 30tabs","Enervon","Health & Wellness",285.00,"{""size"": ""30tablets"", ""package"": ""bottle"", ""type"": ""multivitamin""}"
EOF
    echo "   ✅ Generated sample_sku_catalog.csv"
fi

# 3) Upload all CSV files to bucket
echo ""
echo "📤 Uploading seed files to storage bucket..."

files=(
    "ref_sources.csv"
    "ref_categories.csv"
    "ref_brands.csv"
    "health_category_rules.csv"
    "seasonality_factors.csv"
    "sample_sku_catalog.csv"
)

uploaded_count=0
for file in "${files[@]}"; do
    if [ -f "$DATA_DIR/$file" ]; then
        echo "   📄 Uploading $file..."
        if supabase storage upload --bucket "$BUCKET_NAME" "$file" "$DATA_DIR/$file" --overwrite 2>/dev/null; then
            echo "      ✅ Uploaded successfully"
            uploaded_count=$((uploaded_count + 1))
        else
            echo "      ❌ Upload failed"
        fi
    else
        echo "      ⚠️  File not found: $DATA_DIR/$file"
    fi
done

echo ""
echo "📊 UPLOAD SUMMARY"
echo "=================="
echo "✅ Files uploaded: $uploaded_count/$(echo ${#files[@]})"
echo ""

# 4) Verify uploads by testing URLs
echo "🔍 Verifying uploaded files..."
for file in "${files[@]}"; do
    url="https://$PROJECT_REF.supabase.co/storage/v1/object/public/$BUCKET_NAME/$file"
    if curl -s -f -I "$url" >/dev/null 2>&1; then
        echo "   ✅ $file - accessible"
    else
        echo "   ❌ $file - not accessible"
    fi
done

echo ""
echo "🎯 NEXT STEPS:"
echo "=============="
echo "1. Run migration: supabase db push"
echo "2. Load seed data: SELECT scout.fn_load_seed_data();"
echo "3. Verify seeding: SELECT * FROM scout.fn_validate_seed_bucket();"
echo ""
echo "📋 Storage URLs:"
echo "Base URL: https://$PROJECT_REF.supabase.co/storage/v1/object/public/$BUCKET_NAME/"
for file in "${files[@]}"; do
    echo "  $file: https://$PROJECT_REF.supabase.co/storage/v1/object/public/$BUCKET_NAME/$file"
done
echo ""
echo "🚀 Seed data upload completed!"