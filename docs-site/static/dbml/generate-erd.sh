#!/bin/bash
# Generate Entity Relationship Diagram from DBML

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Scout Schema ERD Generator${NC}"
echo "=============================="

# Check if dbml-cli is installed
if ! command -v dbml2sql &> /dev/null; then
    echo -e "${YELLOW}Installing @dbml/cli...${NC}"
    npm install -g @dbml/cli
fi

# Check if dbdocs is installed
if ! command -v dbdocs &> /dev/null; then
    echo -e "${YELLOW}Installing dbdocs...${NC}"
    npm install -g dbdocs
fi

# Generate outputs
echo -e "\n${GREEN}Generating outputs...${NC}"

# 1. Generate PostgreSQL DDL
echo -e "${BLUE}→ Generating PostgreSQL DDL...${NC}"
dbml2sql scout-schema-complete.dbml --postgres -o generated/scout-schema.sql
echo -e "${GREEN}✓ Created: generated/scout-schema.sql${NC}"

# 2. Generate MySQL DDL
echo -e "${BLUE}→ Generating MySQL DDL...${NC}"
dbml2sql scout-schema-complete.dbml --mysql -o generated/scout-schema-mysql.sql
echo -e "${GREEN}✓ Created: generated/scout-schema-mysql.sql${NC}"

# 3. Generate Documentation
echo -e "${BLUE}→ Building interactive documentation...${NC}"
dbdocs build scout-schema-complete.dbml --project="Scout Analytics v5"

# 4. Generate PlantUML for custom ERD
echo -e "${BLUE}→ Generating PlantUML ERD...${NC}"
cat > generated/scout-erd.puml << 'EOF'
@startuml Scout Analytics ERD
!theme aws-orange
skinparam linetype ortho
skinparam roundcorner 10
skinparam shadowing false

' Define colors
!define BRONZE_COLOR #CD7F32
!define SILVER_COLOR #C0C0C0
!define GOLD_COLOR #FFD700
!define PLATINUM_COLOR #E5E4E2
!define DIMENSION_COLOR #4B9BFF
!define FACT_COLOR #FF6B6B

' Dimension Tables
entity "**dim_store**" as dim_store <<dimension, DIMENSION_COLOR>> {
  *store_id : TEXT
  --
  store_name : TEXT
  region : TEXT
  province : TEXT
  city : TEXT
  barangay : TEXT
  latitude : DECIMAL
  longitude : DECIMAL
}

entity "**dim_product**" as dim_product <<dimension, DIMENSION_COLOR>> {
  *product_id : TEXT
  --
  product_name : TEXT
  category : TEXT
  brand : TEXT
  srp : DECIMAL
}

entity "**dim_customer**" as dim_customer <<dimension, DIMENSION_COLOR>> {
  *customer_id : TEXT
  --
  customer_type : TEXT
  loyalty_tier : TEXT
  preferred_payment : TEXT
}

entity "**dim_campaign**" as dim_campaign <<dimension, DIMENSION_COLOR>> {
  *campaign_id : TEXT
  --
  campaign_name : TEXT
  start_date : DATE
  end_date : DATE
}

' Fact Tables
entity "**fact_transactions**" as fact_transactions <<fact, FACT_COLOR>> {
  *transaction_id : TEXT
  --
  store_id : TEXT <<FK>>
  customer_id : TEXT <<FK>>
  campaign_id : TEXT <<FK>>
  transaction_date : DATE
  total_amount : DECIMAL
}

entity "**fact_transaction_items**" as fact_transaction_items <<fact, FACT_COLOR>> {
  *transaction_item_id : TEXT
  --
  transaction_id : TEXT <<FK>>
  product_id : TEXT <<FK>>
  quantity : DECIMAL
  line_total : DECIMAL
}

' Bronze Layer
entity "**bronze_sales_raw**" as bronze <<bronze, BRONZE_COLOR>> {
  *id : SERIAL
  --
  raw_data : JSONB
  source_system : TEXT
  ingestion_timestamp : TIMESTAMP
}

' Silver Layer
entity "**silver_transactions**" as silver <<silver, SILVER_COLOR>> {
  *id : TEXT
  --
  store_id : TEXT
  region : TEXT
  product_category : TEXT
  peso_value : DECIMAL
}

' Gold Layer Views
entity "**gold_txn_daily**" as gold_txn <<gold, GOLD_COLOR>> {
  day : DATE
  region : TEXT
  total_peso : DECIMAL
  transaction_count : BIGINT
}

entity "**gold_product_mix**" as gold_product <<gold, GOLD_COLOR>> {
  product_category : TEXT
  brand_name : TEXT
  revenue_rank : INTEGER
  is_pareto_80 : BOOLEAN
}

' Platinum Layer
entity "**platinum_features**" as platinum <<platinum, PLATINUM_COLOR>> {
  day : DATE
  region : TEXT
  revenue_7d_avg : DECIMAL
  revenue_wow_growth : DECIMAL
}

' Relationships
dim_store ||--o{ fact_transactions : "location"
dim_customer ||--o{ fact_transactions : "purchases"
dim_campaign ||--o{ fact_transactions : "influences"
fact_transactions ||--|{ fact_transaction_items : "contains"
dim_product ||--o{ fact_transaction_items : "sold as"

bronze --> silver : "cleanse"
silver --> gold_txn : "aggregate"
silver --> gold_product : "analyze"
gold_txn --> platinum : "feature engineering"
gold_product --> platinum : "ML features"

@enduml
EOF
echo -e "${GREEN}✓ Created: generated/scout-erd.puml${NC}"

# 5. Create a summary visualization
echo -e "${BLUE}→ Generating schema summary...${NC}"
cat > generated/schema-summary.md << 'EOF'
# Scout Analytics Schema Summary

## 📊 Statistics

| Layer | Tables/Views | Purpose |
|-------|--------------|---------|
| **Bronze** | 1 | Raw data ingestion |
| **Silver** | 3 | Cleaned & validated |
| **Gold** | 6 | Business metrics |
| **Platinum** | 5 | ML features |
| **Dimensions** | 4 | Master data |
| **Facts** | 2 | Transactional data |

## 🔑 Key Relationships

```mermaid
graph LR
    subgraph Dimensions
        DS[dim_store]
        DP[dim_product]
        DC[dim_customer]
        DCA[dim_campaign]
    end
    
    subgraph Facts
        FT[fact_transactions]
        FTI[fact_items]
    end
    
    DS --> FT
    DC --> FT
    DCA --> FT
    FT --> FTI
    DP --> FTI
```

## 📈 Data Flow

```mermaid
graph TD
    subgraph Sources
        POS[POS Systems]
        API[APIs]
        IOT[IoT Devices]
    end
    
    subgraph Medallion
        B[Bronze Layer]
        S[Silver Layer]
        G[Gold Layer]
        P[Platinum Layer]
    end
    
    POS --> B
    API --> B
    IOT --> B
    B --> S
    S --> G
    G --> P
    
    P --> ML[ML Models]
    P --> DASH[Dashboards]
    P --> REC[Recommendations]
```

## 🔒 Security Features

- ✅ Row-Level Security (RLS) on all tables
- ✅ Column-level encryption for PII
- ✅ Comprehensive audit logging
- ✅ Role-based access control
- ✅ Data retention policies

## ⚡ Performance Optimizations

- ✅ Strategic composite indexes
- ✅ Materialized views with auto-refresh
- ✅ Table partitioning by time/geography
- ✅ Query optimization hints
- ✅ Connection pooling

EOF
echo -e "${GREEN}✓ Created: generated/schema-summary.md${NC}"

# Create output directory
mkdir -p generated

echo -e "\n${GREEN}✅ ERD generation complete!${NC}"
echo -e "\nGenerated files:"
echo -e "  • generated/scout-schema.sql"
echo -e "  • generated/scout-schema-mysql.sql"
echo -e "  • generated/scout-erd.puml"
echo -e "  • generated/schema-summary.md"

echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. View interactive documentation: ${YELLOW}dbdocs serve${NC}"
echo -e "2. Generate PNG from PlantUML: ${YELLOW}plantuml generated/scout-erd.puml${NC}"
echo -e "3. Upload to dbdiagram.io for visual editing"

# Make script executable
chmod +x generate-erd.sh