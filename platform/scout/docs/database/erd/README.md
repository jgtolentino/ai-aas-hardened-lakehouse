# Scout Platform Database Documentation

Generated on: 2025-09-03 18:13:41

## 📊 Entity Relationship Diagrams

This directory contains comprehensive database documentation for the Scout Analytics Platform, organized using Medallion Architecture principles.

### 🏗️ Architecture Overview

The Scout Platform implements a **Medallion Architecture** with four distinct layers:

- **🥉 Bronze Layer**: Raw data ingestion from POS systems, APIs, and file imports
- **🥈 Silver Layer**: Cleaned, validated, and enriched transactional data
- **🥇 Gold Layer**: Business-ready aggregates and KPIs (PUBLIC with RLS)
- **💎 Platinum Layer**: ML models, predictions, and advanced analytics (PUBLIC with RLS)

### 📁 Documentation Structure

#### SQL Schema
- `sql/scout-platform-schema.sql` - Complete PostgreSQL schema definition
- Generated from DBML with full table definitions, indexes, and constraints

#### Mermaid Diagrams
- `mermaid/complete-erd.mmd` - Complete system ERD
- `mermaid/bronze-layer.mmd` - Bronze layer tables and relationships
- `mermaid/silver-layer.mmd` - Silver layer core business entities
- `mermaid/gold-layer.mmd` - Gold layer analytics and KPIs
- `mermaid/platinum-layer.mmd` - Platinum layer ML and AI models
- `mermaid/governance-layer.mmd` - Governance and metadata tables

#### GraphViz Diagrams
- `graphviz/scout-platform-erd.dot` - High-level architecture visualization

### 🚀 Usage

#### Viewing Mermaid Diagrams
1. **GitHub**: Mermaid diagrams render automatically in GitHub markdown
2. **VS Code**: Use the "Mermaid Preview" extension
3. **Online**: Copy content to [mermaid.live](https://mermaid.live/)

#### Generating Images from GraphViz
```bash
# Install GraphViz if not already installed
brew install graphviz  # macOS
sudo apt-get install graphviz  # Ubuntu

# Generate PNG
dot -Tpng graphviz/scout-platform-erd.dot -o images/scout-platform-erd.png

# Generate SVG (scalable)
dot -Tsvg graphviz/scout-platform-erd.dot -o images/scout-platform-erd.svg
```

### 🔒 Security & Access Control

#### Public Schemas (RLS Enabled)
- **scout_gold.\***: Business analytics and KPIs
- **scout_platinum.\***: ML models and predictions

#### Internal Schemas (Service Access Only)
- **scout_bronze.\***: Raw data ingestion
- **scout_silver.\***: Cleaned transactional data
- **scout.\***: Governance and metadata

### 📋 Key Business Entities

#### Core Transactions
- **scout_silver.transactions**: Main transaction records
- **scout_silver.transaction_items**: Individual line items
- **scout_silver.stores**: Philippine store locations
- **scout_silver.products**: Product catalog
- **scout_silver.customers**: Customer profiles

#### Analytics & KPIs
- **scout_gold.kpi_daily_summary**: Daily business metrics
- **scout_gold.product_performance**: Product analytics
- **scout_gold.customer_segments**: Customer behavior analysis
- **scout_gold.store_performance**: Store operational metrics

#### ML & Predictions
- **scout_platinum.demand_forecast**: Inventory demand predictions
- **scout_platinum.price_optimization**: Dynamic pricing recommendations
- **scout_platinum.customer_lifetime_value**: CLV predictions and risk assessment
- **scout_platinum.anomaly_detection**: Automated anomaly detection

### 🇵🇭 Philippine Market Features

- **Geographic Data**: Complete PSGC (Philippine Standard Geographic Code) integration
- **Regional Analytics**: NCR, Luzon, Visayas, Mindanao segmentation
- **Holiday Calendar**: Philippine holidays for seasonal analysis
- **Payment Methods**: Local payment systems (GCash, PayMaya, etc.)
- **Multi-language Support**: English, Filipino, Cebuano, Ilocano, Waray

### 🔄 Data Lineage

Data flows through the medallion layers with complete lineage tracking:

1. **Ingestion**: Raw data → Bronze layer
2. **Transformation**: Bronze → Silver (cleaning, validation)
3. **Aggregation**: Silver → Gold (business metrics)
4. **Analytics**: Gold → Platinum (ML predictions)

### 📈 Regenerating Documentation

To update the documentation when the schema changes:

```bash
# From project root
./scripts/generate-erd.sh

# This will regenerate:
# - SQL schema from DBML
# - All Mermaid diagrams
# - GraphViz visualizations
# - This documentation index
```

---

**Last Updated**: 2025-09-03 18:13:41  
**Schema Version**: 1.0.0  
**DBML Source**: `platform/scout/docs/database/scout-platform-schema.dbml`
